const SUPPORT_EMAIL = 'support@ttmttm.com';
const ALLOWED_CATEGORIES = new Set(['account', 'identity', 'app', 'payment', 'other']);
const CATEGORY_LABELS = {
  account: '계정',
  identity: '본인확인',
  app: '앱 오류',
  payment: '지갑·결제',
  other: '기타',
};

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

function parseInquiry(body) {
  const email = String(body?.email || '').trim().toLowerCase();
  const category = String(body?.category || '').trim();
  const subject = String(body?.subject || '').trim();
  const message = String(body?.message || '').trim();
  const website = String(body?.website || '').trim();
  const validEmail = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i.test(email);

  if (website) return { error: 'spam_detected' };
  if (!validEmail) return { error: 'invalid_email' };
  if (!ALLOWED_CATEGORIES.has(category)) return { error: 'invalid_args' };
  if (subject.length < 2 || subject.length > 120) return { error: 'invalid_args' };
  if (message.length < 5 || message.length > 2000) return { error: 'invalid_args' };
  return { email, category, subject, message };
}

async function storeInquiry(config, inquiry) {
  const response = await fetch(
    `${config.supabaseUrl}/rest/v1/rpc/submit_web_support_inquiry`,
    {
      method: 'POST',
      headers: {
        apikey: config.publishableKey,
        Authorization: `Bearer ${config.publishableKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_email: inquiry.email,
        p_category: inquiry.category,
        p_subject: inquiry.subject,
        p_message: inquiry.message,
      }),
    },
  );
  if (!response.ok) throw new Error('database_insert_failed');
  return response.json();
}

function buildSupportEmail(inquiry, inquiryId) {
  const category = escapeHtml(CATEGORY_LABELS[inquiry.category] || inquiry.category);
  const subject = escapeHtml(inquiry.subject);
  const sender = escapeHtml(inquiry.email);
  const message = escapeHtml(inquiry.message).replaceAll('\n', '<br>');
  const id = escapeHtml(inquiryId || '-');
  return `<!doctype html>
<html lang="ko">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#FBFAF4;color:#1E2A23;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Apple SD Gothic Neo','Malgun Gothic',Arial,sans-serif;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${subject} · ${sender}님의 새 문의입니다.</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FBFAF4;">
    <tr><td align="center" style="padding:36px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#FFFFFF;border-radius:28px;overflow:hidden;box-shadow:0 12px 36px rgba(30,50,35,.10);">
        <tr><td style="padding:30px 34px 26px;background:#2EA86A;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>
            <td width="58" valign="middle"><img src="https://www.ttmttm.com/assets/store-icon.png" width="52" height="52" alt="틈틈" style="display:block;border:0;border-radius:14px;"></td>
            <td valign="middle" style="padding-left:14px;color:#FFFFFF;"><div style="font-size:20px;font-weight:800;letter-spacing:-.03em;">틈틈 고객센터</div><div style="margin-top:3px;font-size:12px;font-weight:700;letter-spacing:.16em;opacity:.82;">TTM SUPPORT</div></td>
          </tr></table>
          <div style="margin-top:30px;color:#FFFFFF;font-size:30px;line-height:1.25;font-weight:800;letter-spacing:-.04em;">새로운 문의가<br>도착했습니다</div>
          <div style="margin-top:10px;color:#E8FFF1;font-size:14px;line-height:1.6;">내용을 확인한 뒤 이 메일에 바로 답장할 수 있습니다.</div>
        </td></tr>
        <tr><td style="padding:30px 34px 10px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#EEF4EF;border-radius:18px;">
            <tr><td style="padding:18px 20px;border-bottom:1px solid #DDEEE3;color:#647169;font-size:13px;font-weight:700;">문의 유형</td><td align="right" style="padding:18px 20px;border-bottom:1px solid #DDEEE3;color:#15803F;font-size:14px;font-weight:800;">${category}</td></tr>
            <tr><td style="padding:18px 20px;border-bottom:1px solid #DDEEE3;color:#647169;font-size:13px;font-weight:700;">보낸 사람</td><td align="right" style="padding:18px 20px;border-bottom:1px solid #DDEEE3;color:#1E2A23;font-size:14px;font-weight:700;word-break:break-all;">${sender}</td></tr>
            <tr><td style="padding:18px 20px;color:#647169;font-size:13px;font-weight:700;">접수 번호</td><td align="right" style="padding:18px 20px;color:#1E2A23;font-family:Consolas,Monaco,monospace;font-size:12px;">${id}</td></tr>
          </table>
        </td></tr>
        <tr><td style="padding:22px 34px 8px;">
          <div style="color:#9AA0A0;font-size:12px;font-weight:800;letter-spacing:.08em;">문의 제목</div>
          <div style="margin-top:8px;color:#1E2A23;font-size:22px;line-height:1.4;font-weight:800;letter-spacing:-.03em;">${subject}</div>
        </td></tr>
        <tr><td style="padding:16px 34px 8px;">
          <div style="padding:22px;background:#FBFAF4;border:1px solid #EFECE3;border-radius:18px;color:#3D423C;font-size:15px;line-height:1.75;word-break:break-word;">${message}</div>
        </td></tr>
        <tr><td align="center" style="padding:24px 34px 34px;">
          <a href="https://admin.ttmttm.com/support?inquiry=${id}" style="display:block;padding:16px 24px;background:#2EA86A;border-radius:14px;color:#FFFFFF;text-decoration:none;font-size:15px;font-weight:800;">관리자 페이지에서 답변하기</a>
          <div style="margin-top:13px;color:#9AA0A0;font-size:12px;line-height:1.6;">브랜드 디자인 답변을 보내려면 관리자 페이지를 이용해 주세요.</div>
        </td></tr>
        <tr><td style="padding:22px 34px;background:#EEF4EF;color:#647169;font-size:11px;line-height:1.7;text-align:center;">틈틈(TTM) · 자투리 시간과 심부름을 잇는 매칭 서비스<br><a href="https://www.ttmttm.com/support.html" style="color:#15803F;text-decoration:none;font-weight:700;">고객센터 열기</a></td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

async function sendSupportEmail(inquiry, inquiryId) {
  const apiKey = process.env.RESEND_API_KEY || '';
  if (!apiKey) return { sent: false, reason: 'email_not_configured' };

  const from = process.env.SUPPORT_FROM_EMAIL || `TTM 고객센터 <${SUPPORT_EMAIL}>`;
  const categoryLabel = CATEGORY_LABELS[inquiry.category] || inquiry.category;
  const html = buildSupportEmail(inquiry, inquiryId);
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `support-inquiry-${inquiryId}`,
    },
    body: JSON.stringify({
      from,
      to: [SUPPORT_EMAIL],
      reply_to: inquiry.email,
      subject: `[TTM 고객센터] ${inquiry.subject}`,
      html,
      text: `새 고객 문의가 접수되었습니다.\n\n문의 유형: ${categoryLabel}\n보낸 사람: ${inquiry.email}\n접수 번호: ${inquiryId || '-'}\n제목: ${inquiry.subject}\n\n${inquiry.message}`,
    }),
  });
  if (!response.ok) return { sent: false, reason: 'email_provider_failed' };
  return { sent: true };
}

export default async function handler(request, response) {
  if (request.method !== 'POST') {
    response.setHeader('Allow', 'POST');
    return json(response, 405, { ok: false, reason: 'method_not_allowed' });
  }

  const inquiry = parseInquiry(request.body);
  if (inquiry.error) return json(response, 400, { ok: false, reason: inquiry.error });

  const supabaseUrl = process.env.SUPABASE_URL || '';
  const publishableKey =
    process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || '';
  if (!supabaseUrl || !publishableKey) {
    return json(response, 503, { ok: false, reason: 'support_not_configured' });
  }

  try {
    const stored = await storeInquiry({ supabaseUrl, publishableKey }, inquiry);
    const delivery = await sendSupportEmail(inquiry, stored?.id);
    return json(response, 200, {
      ok: true,
      inquiryId: stored?.id || null,
      emailSent: delivery.sent,
      emailReason: delivery.sent ? null : delivery.reason,
    });
  } catch (_error) {
    return json(response, 502, { ok: false, reason: 'support_submit_failed' });
  }
}
