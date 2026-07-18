// 틈틈(TTM) 매칭 단계 진행 Edge Function.
// stage 진행 후 push_outbox 를 즉시 처리한다 (FCM HTTP v1).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { processPushOutbox } from "../_shared/push_gateway.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false } },
);

interface AdvanceResult {
  ok: boolean;
  reason?: string;
  status?: string;
  stage?: number;
  radius_m?: number;
  inserted?: number;
  next_advance_at?: string;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

async function flushPushOutbox(): Promise<Record<string, unknown>> {
  try {
    const result = await processPushOutbox(supabase, 40);
    return result;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[match-tick] push outbox flush failed", msg);
    return { processed: 0, sent: 0, skipped: 0, failed: 0, error: msg };
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ ok: false, reason: "method_not_allowed" }, 405);
  }

  let body: { request_id?: string; flush_only?: boolean } = {};
  try {
    if (req.headers.get("content-length") !== "0") {
      body = (await req.json()) as {
        request_id?: string;
        flush_only?: boolean;
      };
    }
  } catch (_) {
    body = {};
  }

  if (body.flush_only) {
    const push = await flushPushOutbox();
    return jsonResponse({ ok: true, push });
  }

  let advanceResult: AdvanceResult | { ok: boolean; advanced?: number };

  if (body.request_id) {
    const { data, error } = await supabase.rpc("advance_request_stage", {
      p_request_id: body.request_id,
    });
    if (error) {
      return jsonResponse({ ok: false, error: error.message }, 400);
    }
    advanceResult = data as AdvanceResult;
  } else {
    const { data, error } = await supabase.rpc("tick_all_due_requests");
    if (error) {
      return jsonResponse({ ok: false, error: error.message }, 400);
    }
    advanceResult = { ok: true, advanced: data ?? 0 };
  }

  const push = await flushPushOutbox();

  return jsonResponse({
    ...(typeof advanceResult === "object" ? advanceResult : { ok: true }),
    push,
  });
});
