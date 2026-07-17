const SUPPORT_EMAIL = 'support@ttmttm.com';
const ALLOWED_ORIGINS = new Set([
  'https://admin.ttmttm.com',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
]);

function setCors(request, response) {
  const origin = String(request.headers.origin || '');
  if (ALLOWED_ORIGINS.has(origin)) {
    response.setHeader('Access-Control-Allow-Origin', origin);
    response.setHeader('Vary', 'Origin');
  }
  response.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  return !origin || ALLOWED_ORIGINS.has(origin);
}

function json(response, status, body) {
  response.setHeader('Cache-Control', 'no-store');
  return response.status(status).json(body);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

async function supabaseRequest(config, path, options = {}) {
  return fetch(`${config.url}${path}`, {
    ...options,
    headers: {
      apikey: config.key,
      Authorization: `Bearer ${config.token}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
}

async function assertAdmin(config) {
  const response = await supabaseRequest(config, '/rest/v1/rpc/my_is_admin', {
    method: 'POST',
    body: '{}',
  });
  if (!response.ok || (await response.json()) !== true) throw new Error('forbidden');
}

async function loadInquiry(config, inquiryId) {
  const query = new URLSearchParams({
    id: `eq.${inquiryId}`,
    select: 'id,email,subject,message,status',
    limit: '1',
  });
  const response = await supabaseRequest(config, `/rest/v1/web_support_inquiries?${query}`);
  if (!response.ok) throw new Error('inquiry_lookup_failed');
  const rows = await response.json();
  if (!Array.isArray(rows) || !rows[0]) throw new Error('not_found');
  return rows[0];
}

function buildReplyEmail(inquiry, reply) {
  const subject = escapeHtml(inquiry.subject);
  const originalMessage = escapeHtml(inquiry.message).replaceAll('\n', '<br>');
  const replyMessage = escapeHtml(reply).replaceAll('\n', '<br>');

  return `<!doctype html>
<html lang="ko">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#FBFAF4;color:#1E2A23;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Apple SD Gothic Neo','Malgun Gothic',Arial,sans-serif;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${subject} 문의에 대한 틈틈 고객센터 답변입니다.</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FBFAF4;">
    <tr><td align="center" style="padding:36px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#FFFFFF;border-radius:28px;overflow:hidden;box-shadow:0 12px 36px rgba(30,50,35,.10);">
        <tr><td style="padding:30px 34px 28px;background:#2EA86A;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
            <td width="58" valign="middle"><img src="https://www.ttmttm.com/assets/store-icon.png" width="52" height="52" alt="틈틈" style="display:block;border:0;border-radius:14px;"></td>
            <td valign="middle" style="padding-left:14px;color:#FFFFFF;"><div style="font-size:20px;font-weight:800;letter-spacing:-.03em;">틈틈 고객센터</div><div style="margin-top:3px;font-size:12px;font-weight:700;letter-spacing:.16em;opacity:.82;">TTM SUPPORT</div></td>
          </tr></table>
          <div style="margin-top:30px;color:#FFFFFF;font-size:30px;line-height:1.25;font-weight:800;letter-spacing:-.04em;">문의하신 내용에<br>답변드려요</div>
          <div style="margin-top:10px;color:#E8FFF1;font-size:14px;line-height:1.6;">틈틈을 이용해 주셔서 감사합니다.</div>
        </td></tr>
        <tr><td style="padding:30px 34px 8px;">
          <div style="color:#9AA0A0;font-size:12px;font-weight:800;letter-spacing:.08em;">문의 제목</div>
          <div style="margin-top:8px;color:#1E2A23;font-size:20px;line-height:1.4;font-weight:800;letter-spacing:-.03em;">${subject}</div>
        </td></tr>
        <tr><td style="padding:16px 34px 8px;">
          <div style="padding:24px;background:#EEF4EF;border-radius:18px;color:#1E2A23;font-size:15px;line-height:1.8;word-break:break-word;">${replyMessage}</div>
        </td></tr>
        <tr><td style="padding:22px 34px 8px;">
          <div style="color:#9AA0A0;font-size:12px;font-weight:800;letter-spacing:.08em;">보내주신 내용</div>
          <div style="margin-top:9px;padding:18px 20px;border-left:3px solid #DDEEE3;background:#FBFAF4;color:#647169;font-size:13px;line-height:1.7;word-break:break-word;">${originalMessage}</div>
        </td></tr>
        <tr><td align="center" style="padding:26px 34px 34px;">
          <a href="https://www.ttmttm.com/support.html" style="display:block;padding:16px 24px;background:#2EA86A;border-radius:14px;color:#FFFFFF;text-decoration:none;font-size:15px;font-weight:800;">틈틈 고객센터 열기</a>
        </td></tr>
        <tr><td style="padding:22px 34px;background:#EEF4EF;color:#647169;font-size:11px;line-height:1.7;text-align:center;">틈틈(TTM) · 자투리 시간과 심부름을 잇는 매칭 서비스<br>추가 문의: <a href="mailto:${SUPPORT_EMAIL}" style="color:#15803F;text-decoration:none;font-weight:700;">${SUPPORT_EMAIL}</a></td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

async function sendReply(inquiry, reply) {
  const apiKey = process.env.RESEND_API_KEY || '';
  if (!apiKey) throw new Error('email_not_configured');
  const from = process.env.SUPPORT_FROM_EMAIL || `틈틈 고객센터 <${SUPPORT_EMAIL}>`;
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `support-reply-${inquiry.id}-${Date.now()}`,
    },
    body: JSON.stringify({
      from,
      to: [inquiry.email],
      reply_to: SUPPORT_EMAIL,
      subject: `[틈틈 고객센터 답변] ${inquiry.subject}`,
      html: buildReplyEmail(inquiry, reply),
      text: `문의하신 내용에 답변드립니다.\n\n${reply}\n\n문의 제목: ${inquiry.subject}\n보내주신 내용: ${inquiry.message}\n\n틈틈 고객센터`,
    }),
  });
  if (!response.ok) throw new Error('email_provider_failed');
}

async function markResolved(config, inquiryId, reply) {
  const response = await supabaseRequest(config, '/rest/v1/rpc/admin_update_web_support_inquiry', {
    method: 'POST',
    body: JSON.stringify({
      p_inquiry_id: inquiryId,
      p_status: 'resolved',
      p_admin_note: reply,
    }),
  });
  if (!response.ok) throw new Error('status_update_failed');
}

export default async function handler(request, response) {
  const allowedOrigin = setCors(request, response);
  if (request.method === 'OPTIONS') return response.status(204).end();
  if (!allowedOrigin) return json(response, 403, { ok: false, reason: 'origin_not_allowed' });
  if (request.method !== 'POST') {
    response.setHeader('Allow', 'POST, OPTIONS');
    return json(response, 405, { ok: false, reason: 'method_not_allowed' });
  }

  const token = String(request.headers.authorization || '').replace(/^Bearer\s+/i, '').trim();
  const inquiryId = String(request.body?.inquiryId || '').trim();
  const reply = String(request.body?.reply || '').trim();
  if (!token) return json(response, 401, { ok: false, reason: 'unauthorized' });
  if (!/^[0-9a-f-]{36}$/i.test(inquiryId) || reply.length < 2 || reply.length > 4000) {
    return json(response, 400, { ok: false, reason: 'invalid_args' });
  }

  const config = {
    url: process.env.SUPABASE_URL || '',
    key: process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || '',
    token,
  };
  if (!config.url || !config.key) {
    return json(response, 503, { ok: false, reason: 'support_not_configured' });
  }

  try {
    await assertAdmin(config);
    const inquiry = await loadInquiry(config, inquiryId);
    await sendReply(inquiry, reply);
    await markResolved(config, inquiryId, reply);
    return json(response, 200, { ok: true });
  } catch (error) {
    const reason = error instanceof Error ? error.message : 'support_reply_failed';
    const status = reason === 'forbidden' ? 403 : reason === 'not_found' ? 404 : 502;
    return json(response, status, { ok: false, reason });
  }
}
