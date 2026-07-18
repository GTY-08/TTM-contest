/// FCM HTTP v1 (Firebase Admin). Legacy server key 사용하지 않음.

import { JWT } from "npm:google-auth-library@9.15.1";

export type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

let cachedToken: { accessToken: string; expiresAtMs: number } | null = null;

function normalizePrivateKey(key: string): string {
  let k = key.trim();
  for (let i = 0; i < 3; i++) {
    if (k.includes("\\n") && !k.includes("\n")) {
      k = k.replace(/\\n/g, "\n");
    } else {
      break;
    }
  }
  return k;
}

function parseServiceAccountJson(raw: string): ServiceAccount {
  let text = raw.trim().replace(/^\uFEFF/, "");
  if (text.startsWith('"') && text.endsWith('"')) {
    try {
      text = JSON.parse(text) as string;
    } catch (_) {
      /* fall through */
    }
  }
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(text) as ServiceAccount;
  } catch (e) {
    const hint = e instanceof Error ? e.message : String(e);
    throw new Error(`FCM JSON parse failed: ${hint}`);
  }
  if (!sa.project_id || !sa.client_email || !sa.private_key) {
    throw new Error("FCM JSON missing project_id, client_email, or private_key");
  }
  sa.private_key = normalizePrivateKey(sa.private_key);
  if (!sa.private_key.includes("BEGIN PRIVATE KEY")) {
    throw new Error("FCM private_key PEM 형식 오류");
  }
  return sa;
}

export function loadServiceAccountFromEnv(): ServiceAccount {
  const b64 = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON_B64");
  if (b64?.trim()) {
    try {
      return parseServiceAccountJson(atob(b64.trim()));
    } catch (e) {
      const hint = e instanceof Error ? e.message : String(e);
      throw new Error(`FCM_SERVICE_ACCOUNT_JSON_B64: ${hint}`);
    }
  }

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error("FCM_SERVICE_ACCOUNT_JSON secret 없음");
  }
  return parseServiceAccountJson(raw);
}

export async function getFcmAccessToken(
  sa: ServiceAccount,
): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAtMs > now + 60_000) {
    return cachedToken.accessToken;
  }

  const client = new JWT({
    email: sa.client_email,
    key: sa.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const tokenResponse = await client.getAccessToken();
  const token = tokenResponse.token;
  if (!token) {
    throw new Error("FCM OAuth: access token empty");
  }

  cachedToken = {
    accessToken: token,
    expiresAtMs: now + 55 * 60 * 1000,
  };
  return token;
}

export type FcmSendResult = {
  ok: boolean;
  messageName?: string;
  errorCode?: string;
  errorMessage?: string;
  tokenInvalid?: boolean;
};

export type PushPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
  channelId: string;
  priority: "high" | "normal";
  collapseKey?: string;
  vibrate?: boolean;
};

function channelForType(pushType: string): string {
  switch (pushType) {
    case "worker_match_offer":
    case "exercise_match_offer":
    case "raid_recruitment_offer":
      return "ttm_match_offer";
    case "requester_matched":
    case "requester_match_failed":
    case "completion_requested":
    case "request_cancelled":
    case "exercise_match_matched":
    case "raid_recruitment_application":
    case "raid_application_received":
    case "raid_application_approved":
    case "raid_application_waitlisted":
    case "raid_application_rejected":
    case "raid_participant_joined":
    case "raid_participant_cancelled":
      return "ttm_match_result";
    case "chat_message":
    case "exercise_match_message":
    case "raid_application_message":
    case "raid_group_message":
      return "ttm_message";
    case "request_completed":
    case "raid_started":
    case "raid_completed":
    case "exercise_match_completed":
      return "ttm_completion";
    default:
      return "ttm_default";
  }
}

export async function sendFcmToToken(
  sa: ServiceAccount,
  accessToken: string,
  token: string,
  platform: string,
  pushType: string,
  payload: PushPayload,
): Promise<FcmSendResult> {
  const channelId = payload.channelId || channelForType(pushType);
  const androidPriority = payload.priority === "high" ? "HIGH" : "NORMAL";
  const apnsPriority = payload.priority === "high" ? "10" : "5";

  const message: Record<string, unknown> = {
    token,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: {
      ...payload.data,
      push_type: pushType,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: androidPriority,
      notification: {
        channel_id: channelId,
        tag: payload.collapseKey,
        notification_priority: payload.priority === "high"
          ? "PRIORITY_HIGH"
          : "PRIORITY_DEFAULT",
      },
    },
    apns: {
      headers: {
        "apns-priority": apnsPriority,
        "apns-push-type": "alert",
      },
      payload: {
        aps: {
          alert: { title: payload.title, body: payload.body },
          sound: "default",
          "thread-id": payload.collapseKey ?? pushType,
        },
      },
    },
  };

  if (platform === "android" && payload.vibrate === false) {
    (message.android as Record<string, unknown>).notification = {
      ...(message.android as { notification: Record<string, unknown> })
        .notification,
      default_vibrate_timings: false,
    };
  }

  const url =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });

  if (res.ok) {
    const json = await res.json() as { name?: string };
    return { ok: true, messageName: json.name };
  }

  const errText = await res.text();
  let errorCode = `http_${res.status}`;
  let tokenInvalid = false;
  try {
    const parsed = JSON.parse(errText) as {
      error?: { details?: Array<{ errorCode?: string }>; message?: string };
    };
    const detailCode = parsed.error?.details?.find((d) => d.errorCode)
      ?.errorCode;
    if (detailCode) errorCode = detailCode;
    if (
      errorCode === "UNREGISTERED" ||
      errorCode === "INVALID_ARGUMENT" ||
      errText.includes("NOT_FOUND")
    ) {
      tokenInvalid = true;
    }
    return {
      ok: false,
      errorCode,
      errorMessage: parsed.error?.message ?? errText,
      tokenInvalid,
    };
  } catch {
    return { ok: false, errorCode, errorMessage: errText, tokenInvalid };
  }
}

export { channelForType };
