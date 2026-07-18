import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  channelForType,
  FcmSendResult,
  getFcmAccessToken,
  loadServiceAccountFromEnv,
  sendFcmToToken,
  ServiceAccount,
} from "./fcm_v1.ts";

export type OutboxRow = {
  id: string;
  user_id: string;
  push_type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  collapse_key: string | null;
  priority: string;
  attempt_count: number;
};

export function createServiceSupabase(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );
}

function shouldSendPush(notificationMode: string | null): boolean {
  return notificationMode === "push" ||
    notificationMode === "push_inapp" ||
    notificationMode === "push_inapp_vibrate";
}

function shouldVibrate(notificationMode: string | null): boolean {
  return notificationMode === "push_inapp_vibrate";
}

async function isWorkerOnlineForOffer(
  supabase: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data } = await supabase
    .from("worker_presence")
    .select("status")
    .eq("worker_id", userId)
    .maybeSingle();
  return data?.status === "online";
}

async function isDedupBlocked(
  supabase: SupabaseClient,
  userId: string,
  collapseKey: string | null,
): Promise<boolean> {
  if (!collapseKey) return false;
  const { data } = await supabase
    .from("push_dedup")
    .select("collapse_key")
    .eq("user_id", userId)
    .eq("collapse_key", collapseKey)
    .maybeSingle();
  return data != null;
}

async function markDedup(
  supabase: SupabaseClient,
  userId: string,
  collapseKey: string | null,
): Promise<void> {
  if (!collapseKey) return;
  await supabase.from("push_dedup").upsert({
    user_id: userId,
    collapse_key: collapseKey,
    sent_at: new Date().toISOString(),
  });
}

function dataAsStrings(data: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v == null) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

export type ProcessOutboxResult = {
  processed: number;
  sent: number;
  skipped: number;
  failed: number;
};

export async function processPushOutbox(
  supabase: SupabaseClient,
  limit = 30,
): Promise<ProcessOutboxResult> {
  const sa = loadServiceAccountFromEnv();
  const accessToken = await getFcmAccessToken(sa);

  const { data: rows, error } = await supabase
    .from("push_outbox")
    .select("*")
    .eq("status", "pending")
    .lte("scheduled_at", new Date().toISOString())
    .order("created_at", { ascending: true })
    .limit(limit);

  if (error) throw error;
  if (!rows || rows.length === 0) {
    return { processed: 0, sent: 0, skipped: 0, failed: 0 };
  }

  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (const row of rows as OutboxRow[]) {
    await supabase.from("push_outbox")
      .update({ status: "processing", attempt_count: row.attempt_count + 1 })
      .eq("id", row.id);

    const outcome = await deliverOutboxRow(supabase, sa, accessToken, row);
    if (outcome === "sent") sent++;
    else if (outcome === "skipped") skipped++;
    else failed++;
  }

  return { processed: rows.length, sent, skipped, failed };
}

async function deliverOutboxRow(
  supabase: SupabaseClient,
  sa: ServiceAccount,
  accessToken: string,
  row: OutboxRow,
): Promise<"sent" | "skipped" | "failed"> {
  const { data: userRow } = await supabase
    .from("users")
    .select("notification_mode")
    .eq("id", row.user_id)
    .maybeSingle();

  if (!shouldSendPush(userRow?.notification_mode ?? "push")) {
    await supabase.from("push_outbox").update({
      status: "skipped",
      last_error: "notification_mode_off",
      sent_at: new Date().toISOString(),
    }).eq("id", row.id);
    return "skipped";
  }

  if (
    row.push_type === "worker_match_offer" ||
    row.push_type === "exercise_match_offer"
  ) {
    const online = await isWorkerOnlineForOffer(supabase, row.user_id);
    if (!online) {
      await supabase.from("push_outbox").update({
        status: "skipped",
        last_error: "worker_offline",
        sent_at: new Date().toISOString(),
      }).eq("id", row.id);
      return "skipped";
    }
  }

  if (await isDedupBlocked(supabase, row.user_id, row.collapse_key)) {
    await supabase.from("push_outbox").update({
      status: "skipped",
      last_error: "dedup",
      sent_at: new Date().toISOString(),
    }).eq("id", row.id);
    return "skipped";
  }

  const { data: tokens } = await supabase
    .from("fcm_tokens")
    .select("token, platform")
    .eq("user_id", row.user_id);

  if (!tokens || tokens.length === 0) {
    await supabase.from("push_outbox").update({
      status: "failed",
      last_error: "no_tokens",
    }).eq("id", row.id);
    return "failed";
  }

  const payload = {
    title: row.title,
    body: row.body,
    data: dataAsStrings(row.data ?? {}),
    channelId: channelForType(row.push_type),
    priority: (row.priority === "normal" ? "normal" : "high") as "high" | "normal",
    collapseKey: row.collapse_key ?? undefined,
    vibrate: shouldVibrate(userRow?.notification_mode ?? "push"),
  };

  let anySuccess = false;
  let lastError = "";

  for (const t of tokens) {
    let result: FcmSendResult;
    try {
      result = await sendFcmToToken(
        sa,
        accessToken,
        t.token,
        t.platform,
        row.push_type,
        payload,
      );
    } catch (e) {
      result = {
        ok: false,
        errorMessage: e instanceof Error ? e.message : String(e),
      };
    }

    await supabase.from("push_delivery_log").insert({
      outbox_id: row.id,
      user_id: row.user_id,
      push_type: row.push_type,
      fcm_token: t.token,
      platform: t.platform,
      fcm_message_name: result.messageName ?? null,
      success: result.ok,
      error_code: result.errorCode ?? null,
      error_message: result.errorMessage ?? null,
    });

    if (result.tokenInvalid) {
      await supabase.from("fcm_tokens").delete().eq("token", t.token);
    }

    if (result.ok) anySuccess = true;
    else lastError = result.errorMessage ?? result.errorCode ?? "send_failed";
  }

  if (anySuccess) {
    await markDedup(supabase, row.user_id, row.collapse_key);
    await supabase.from("push_outbox").update({
      status: "sent",
      sent_at: new Date().toISOString(),
      last_error: null,
    }).eq("id", row.id);
    return "sent";
  }

  await supabase.from("push_outbox").update({
    status: "failed",
    last_error: lastError,
  }).eq("id", row.id);
  return "failed";
}

export function verifyPushSecret(req: Request): boolean {
  const expected = Deno.env.get("PUSH_INTERNAL_SECRET");
  if (!expected) return false;
  return req.headers.get("x-ttm-push-secret") === expected;
}
