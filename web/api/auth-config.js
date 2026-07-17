export default function handler(_request, response) {
  const supabaseUrl = process.env.SUPABASE_URL || '';
  const publishableKey =
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    '';
  const nexbesignIdentityUrl =
    process.env.NEXBESIGN_IDENTITY_URL ||
    'https://verify.ttmttm.com/window_popup.html';
  const mobileokIdentityUrl =
    process.env.MOBILEOK_IDENTITY_URL ||
    process.env.PASS_IDENTITY_URL ||
    'https://verify-dev.ttmttm.com/window_popup.html';
  let parsedNexbesignIdentityUrl;
  let parsedMobileokIdentityUrl;
  try {
    parsedNexbesignIdentityUrl = new URL(nexbesignIdentityUrl);
    parsedMobileokIdentityUrl = new URL(mobileokIdentityUrl);
  } catch (_error) {
    parsedNexbesignIdentityUrl = null;
    parsedMobileokIdentityUrl = null;
  }

  if (
    !supabaseUrl ||
    !publishableKey ||
    !parsedNexbesignIdentityUrl ||
    parsedNexbesignIdentityUrl.protocol !== 'https:' ||
    !parsedMobileokIdentityUrl ||
    parsedMobileokIdentityUrl.protocol !== 'https:'
  ) {
    return response.status(503).json({
      ok: false,
      reason: 'auth_config_missing',
    });
  }

  response.setHeader('Cache-Control', 'public, max-age=300, s-maxage=300');
  return response.status(200).json({
    ok: true,
    supabaseUrl,
    publishableKey,
    identityUrl: mobileokIdentityUrl,
    identityUrls: {
      bankCertificate: nexbesignIdentityUrl,
      pass: mobileokIdentityUrl,
    },
  });
}
