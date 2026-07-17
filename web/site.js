document.querySelectorAll('.reveal').forEach((element, index) => {
  element.style.transitionDelay = `${Math.min(index, 3) * 60}ms`;
});

const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (!entry.isIntersecting) return;
    entry.target.classList.add('on');
    observer.unobserve(entry.target);
  });
}, { threshold: 0.12 });

document.querySelectorAll('.reveal').forEach((element) => observer.observe(element));

function escapeHtml(value) {
  return `${value ?? ''}`
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

async function initAccountNav() {
  const nav = document.querySelector('.nav-actions');
  if (document.getElementById('navAccountLabel')) return;
  if (!nav) return;
  try {
    const [{ createClient }, response] = await Promise.all([
      import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'),
      fetch('/api/auth-config', { headers: { Accept: 'application/json' } }),
    ]);
    const config = await response.json();
    if (!response.ok || !config.ok) return;
    const client = createClient(config.supabaseUrl, config.publishableKey, {
      auth: { persistSession: true, detectSessionInUrl: true, autoRefreshToken: true },
    });
    const render = async () => {
      const { data: { session } } = await client.auth.getSession();
      if (!session) {
        nav.innerHTML = '<a class="btn btn-ghost" href="/account.html">로그인</a><a class="btn btn-primary" href="/account.html">시작하기</a>';
        return;
      }
      const { data: profile, error: profileError } = await client
        .from('users')
        .select('nickname,phone_verified_at,onboarding_completed_at')
        .eq('id', session.user.id)
        .maybeSingle();
      const accountComplete = Boolean(
        !profileError &&
        profile?.phone_verified_at &&
        profile?.onboarding_completed_at,
      );
      if (!accountComplete) {
        nav.innerHTML = '<a class="btn btn-soft" href="/account.html">가입 계속하기</a>';
        return;
      }
      const user = session.user;
      const avatar =
        user.user_metadata?.avatar_url ||
        user.user_metadata?.picture ||
        '';
      const label =
        profile?.nickname ||
        user.user_metadata?.name ||
        user.user_metadata?.full_name ||
        user.email ||
        '내 계정';
      const safeAvatar = escapeHtml(avatar);
      const safeLabel = escapeHtml(label);
      const initial = escapeHtml(label.trim().slice(0, 1).toUpperCase());
      nav.innerHTML = `
        <a class="nav-profile" href="/account.html" aria-label="내 계정">
          ${avatar ? `<img src="${safeAvatar}" alt="">` : `<span>${initial}</span>`}
          <strong>${safeLabel}</strong>
        </a>
      `;
    };
    await render();
    client.auth.onAuthStateChange(() => window.setTimeout(render, 0));
  } catch (_error) {
    // Keep the static login buttons if auth config is unavailable.
  }
}

initAccountNav();
