import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const modal = document.getElementById('accountModal');
const panel = document.getElementById('accountPanel');
const message = document.getElementById('accountMessage');
const authViews = document.querySelectorAll('[data-auth-view]');
const accountButtons = document.querySelectorAll('[data-account-open]');
const closeButton = document.getElementById('accountClose');
const navAccountLabel = document.getElementById('navAccountLabel');
const identityMethodButtons = document.querySelectorAll('[data-identity-method]');

let supabase;
let identityUrl = '';
let identityUrls = {};
let selectedIdentityMethod = 'pass';
let currentProfile = null;
let identityPopup = null;
let identityPollTimer = null;
let identityStatusTimer = null;

function consentStorageKey(userId) {
  return `ttm_web_consents_${userId}`;
}

function readStoredConsents(userId) {
  if (!userId) return null;
  try {
    const raw = window.localStorage.getItem(consentStorageKey(userId));
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (_error) {
    return null;
  }
}

function hasRequiredConsents(userId) {
  const consents = readStoredConsents(userId);
  return Boolean(consents?.terms && consents?.privacy);
}

function storeConsents(userId, values) {
  if (!userId) return;
  const payload = {
    terms: values.get('terms') === 'on',
    privacy: values.get('privacy') === 'on',
    marketing: values.get('marketing') === 'on',
    acceptedAt: new Date().toISOString(),
  };
  window.localStorage.setItem(consentStorageKey(userId), JSON.stringify(payload));
}

function clearConsents(userId) {
  if (userId) window.localStorage.removeItem(consentStorageKey(userId));
}

function setMessage(text = '', kind = '') {
  message.textContent = text;
  message.className = `account-message${kind ? ` ${kind}` : ''}`;
  message.hidden = !text;
}

function showView(name) {
  let activeCount = 0;
  authViews.forEach((view) => {
    const active = view.dataset.authView === name;
    view.hidden = !active;
    view.setAttribute('aria-hidden', active ? 'false' : 'true');
    if (active) activeCount += 1;
  });
  if (activeCount !== 1) {
    authViews.forEach((view) => {
      view.hidden = view.dataset.authView !== 'unavailable';
    });
  }
  setMessage();
  panel.scrollTop = 0;
}

function setIdentityMethod(method) {
  selectedIdentityMethod = method;
  identityMethodButtons.forEach((button) => {
    const active = button.dataset.identityMethod === method;
    button.classList.toggle('active', active);
    button.setAttribute('aria-checked', active ? 'true' : 'false');
  });
}

function goHomeAfterComplete() {
  window.location.assign('/');
}

function isAccountComplete(profile) {
  return Boolean(profile?.phone_verified_at && profile?.onboarding_completed_at);
}

function escapeHtml(value) {
  return `${value ?? ''}`
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function selectedIdentityUrl() {
  return identityUrls[selectedIdentityMethod] || identityUrl;
}

function clearIdentityPoll() {
  if (identityPollTimer) {
    window.clearInterval(identityPollTimer);
    identityPollTimer = null;
  }
  if (identityStatusTimer) {
    window.clearInterval(identityStatusTimer);
    identityStatusTimer = null;
  }
}

async function hasSession() {
  if (!supabase) return false;
  const { data: { session } } = await supabase.auth.getSession();
  return Boolean(session);
}

async function confirmIdentityResultWithRetry(source = 'manual', attempts = 6) {
  for (let i = 0; i < attempts; i += 1) {
    const ok = await confirmIdentityResult(source);
    if (ok) return true;
    await new Promise((resolve) => window.setTimeout(resolve, i === 0 ? 500 : 1200));
  }
  return false;
}

async function confirmIdentityResult(source = 'manual') {
  try {
    if (!(await hasSession())) {
      clearIdentityPoll();
      showView('login');
      if (source === 'manual' || source === 'redirect' || source === 'message') {
        setMessage('로그인 후 본인인증을 진행해 주세요.', 'error');
      }
      return false;
    }
    const profile = await loadProfile();
    if (profile?.phone_verified_at) {
      clearIdentityPoll();
      if (identityPopup && !identityPopup.closed) identityPopup.close();
      identityPopup = null;
      showView('profile');
      setMessage('본인인증이 완료되었습니다. 회원 정보를 입력해 가입을 마무리해 주세요.', 'success');
      return true;
    }
    const { data } = await supabase.rpc('get_my_latest_identity_verification_status');
    const status = data?.status;
    if (status === 'succeeded') {
      clearIdentityPoll();
      showView('profile');
      await loadProfile();
      setMessage('본인인증이 완료되었습니다. 회원 정보를 입력해 가입을 마무리해 주세요.', 'success');
      return true;
    }
    if (['duplicate', 'expired', 'failed', 'invalid'].includes(status)) {
      clearIdentityPoll();
      const messages = {
        duplicate: '이미 다른 계정에서 사용한 본인인증 정보입니다.',
        expired: '인증 시간이 만료되었습니다. 다시 시작해 주세요.',
        failed: '본인인증 결과를 반영하지 못했습니다. 다시 시도해 주세요.',
        invalid: '유효하지 않은 본인인증 결과입니다. 다시 시도해 주세요.',
      };
      setMessage(messages[status] || '본인인증을 완료하지 못했습니다.', 'error');
      return false;
    }
    if (source === 'manual') setMessage('아직 인증 완료가 반영되지 않았습니다.', '');
    return false;
  } catch (error) {
    if (source === 'manual') setMessage(authErrorMessage(error), 'error');
    return false;
  }
}

function openModal(event, refresh = true) {
  event?.preventDefault();
  modal.classList.add('on');
  modal.setAttribute('aria-hidden', 'false');
  if (!document.body.classList.contains('account-page')) {
    document.body.style.overflow = 'hidden';
  }
  if (refresh) refreshAccountView();
}

function closeModal() {
  if (document.body.classList.contains('account-page')) return;
  modal.classList.remove('on');
  modal.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
}

function setBusy(form, busy) {
  form.querySelectorAll('button,input').forEach((element) => {
    element.disabled = busy;
  });
}

function authErrorMessage(error) {
  const raw = `${error?.message || error || ''}`.toLowerCase();
  const code = `${error?.code || ''}`.toLowerCase();
  if (raw.includes('invalid login credentials')) return '이메일 또는 비밀번호가 맞지 않습니다.';
  if (raw.includes('email not confirmed')) return '이메일 인증을 완료한 뒤 로그인해 주세요.';
  if (raw.includes('already registered') || raw.includes('already been registered')) return '이미 가입된 이메일입니다.';
  if (raw.includes('password')) return '비밀번호를 8자 이상 입력해 주세요.';
  if (raw.includes('rate limit')) return '요청이 많습니다. 잠시 후 다시 시도해 주세요.';
  if (code === '23503' || raw.includes('foreign key')) return '계정 프로필을 준비하지 못했습니다. 다시 로그인한 뒤 시도해 주세요.';
  if (code === '42501' || raw.includes('permission denied')) return '계정 저장 권한 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
  if (raw.includes('profile_recovery_failed')) return '계정 프로필을 복구하지 못했습니다. 로그아웃 후 다시 로그인해 주세요.';
  return '처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

function renderIdentityPopup(popup, title, body, failed = false) {
  const color = failed ? '#be123c' : '#0b7a75';
  popup.document.open();
  popup.document.write(`<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title></head><body style="margin:0;background:#f8f7f4;font-family:system-ui,sans-serif;color:#1a1a1a"><main style="max-width:420px;margin:0 auto;padding:56px 24px;text-align:center"><div style="width:64px;height:64px;margin:0 auto 24px;border-radius:20px;background:#e6f4f3;display:grid;place-items:center;color:${color};font-size:30px;font-weight:800">${failed ? '!' : '...'}</div><h1 style="margin:0 0 12px;font-size:24px">${title}</h1><p style="margin:0;color:#6b7280;line-height:1.6">${body}</p>${failed ? '<button onclick="window.close()" style="margin-top:28px;border:0;border-radius:999px;background:#0b7a75;color:white;padding:13px 28px;font-size:16px;font-weight:700">닫기</button>' : ''}</main></body></html>`);
  popup.document.close();
}

async function loadProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from('users')
    .select('id,nickname,phone_verified_at,onboarding_completed_at')
    .eq('id', user.id)
    .maybeSingle();
  if (error) throw error;
  currentProfile = data;
  return data;
}

function updateAccountNav(session, profile = null) {
  if (!navAccountLabel) return;
  if (!session) {
    navAccountLabel.textContent = '로그인';
    navAccountLabel.classList.remove('nav-profile');
    navAccountLabel.classList.remove('btn-soft');
    navAccountLabel.classList.add('btn', 'btn-ghost');
    return;
  }
  if (!isAccountComplete(profile)) {
    navAccountLabel.textContent = '가입 계속하기';
    navAccountLabel.classList.remove('nav-profile');
    navAccountLabel.classList.remove('btn-ghost');
    navAccountLabel.classList.add('btn', 'btn-soft');
    return;
  }
  const user = session.user;
  const avatar = user.user_metadata?.avatar_url || user.user_metadata?.picture || '';
  const label = user.user_metadata?.name || user.user_metadata?.full_name || user.email || '내 계정';
  const safeAvatar = escapeHtml(avatar);
  const safeLabel = escapeHtml(label);
  const initial = escapeHtml(label.trim().slice(0, 1).toUpperCase());
  navAccountLabel.classList.remove('btn', 'btn-ghost', 'btn-soft');
  navAccountLabel.classList.add('nav-profile');
  navAccountLabel.innerHTML = avatar
    ? `<img src="${safeAvatar}" alt=""><strong>${safeLabel}</strong>`
    : `<span>${initial}</span><strong>${safeLabel}</strong>`;
}

async function refreshAccountView() {
  if (!supabase) {
    showView('unavailable');
    return 'unavailable';
  }
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    updateAccountNav(null);
    showView('login');
    return 'login';
  }
  try {
    const profile = await loadProfile();
    updateAccountNav(session, profile);
    if (!hasRequiredConsents(session.user.id) && !profile?.onboarding_completed_at) {
      showView('legal');
      return 'legal';
    }
    if (!profile?.phone_verified_at) {
      showView('identity');
      return 'identity';
    }
    if (!profile?.onboarding_completed_at) {
      showView('profile');
      return 'profile';
    }
    document.getElementById('accountNickname').textContent = profile.nickname || '회원';
    document.getElementById('accountPayoutState').textContent =
      '현재 앱은 시연용 가상 지갑 흐름을 사용합니다. 실제 에스크로와 정산은 추가 예정입니다.';
    showView('complete');
    return 'complete';
  } catch (error) {
    updateAccountNav(null);
    showView('login');
    setMessage(authErrorMessage(error), 'error');
    return 'login';
  }
}

identityMethodButtons.forEach((button) => {
  button.addEventListener('click', () => setIdentityMethod(button.dataset.identityMethod || 'pass'));
});
accountButtons.forEach((button) => button.addEventListener('click', openModal));
closeButton.addEventListener('click', closeModal);
modal.addEventListener('click', (event) => {
  if (event.target === modal) closeModal();
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && modal.classList.contains('on')) closeModal();
});
document.querySelectorAll('[data-auth-go]').forEach((button) => {
  button.addEventListener('click', () => showView(button.dataset.authGo));
});

document.querySelectorAll('[data-oauth-provider]').forEach((button) => {
  button.addEventListener('click', async () => {
    const provider = button.dataset.oauthProvider;
    button.disabled = true;
    setMessage();
    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: { redirectTo: `${window.location.origin}/account.html?auth=oauth` },
    });
    if (error) {
      button.disabled = false;
      setMessage(authErrorMessage(error), 'error');
    }
  });
});

document.getElementById('loginForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  setBusy(form, true);
  setMessage();
  const values = new FormData(form);
  const { error } = await supabase.auth.signInWithPassword({
    email: `${values.get('email')}`.trim(),
    password: `${values.get('password')}`,
  });
  setBusy(form, false);
  if (error) {
    setMessage(authErrorMessage(error), 'error');
    return;
  }
  const view = await refreshAccountView();
  if (view === 'complete') goHomeAfterComplete();
});

document.getElementById('resetPassword').addEventListener('click', async () => {
  const email = `${new FormData(document.getElementById('loginForm')).get('email')}`.trim();
  if (!email.includes('@')) {
    setMessage('이메일을 먼저 입력해 주세요.', 'error');
    return;
  }
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/account.html?auth=recovery`,
  });
  setMessage(error ? authErrorMessage(error) : '비밀번호 재설정 메일을 보냈습니다.', error ? 'error' : 'success');
});

document.getElementById('recoveryForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const values = new FormData(form);
  const password = `${values.get('password')}`;
  if (password.length < 8 || password !== `${values.get('passwordConfirm')}`) {
    setMessage('비밀번호를 8자 이상, 동일하게 입력해 주세요.', 'error');
    return;
  }
  setBusy(form, true);
  const { error } = await supabase.auth.updateUser({ password });
  setBusy(form, false);
  if (error) {
    setMessage(authErrorMessage(error), 'error');
    return;
  }
  await refreshAccountView();
  setMessage('비밀번호를 변경했습니다.', 'success');
});

document.getElementById('signupForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const values = new FormData(form);
  const password = `${values.get('password')}`;
  if (password.length < 8 || password !== `${values.get('passwordConfirm')}`) {
    setMessage('비밀번호를 8자 이상, 동일하게 입력해 주세요.', 'error');
    return;
  }
  setBusy(form, true);
  setMessage();
  const { data, error } = await supabase.auth.signUp({
    email: `${values.get('email')}`.trim(),
    password,
    options: { emailRedirectTo: `${window.location.origin}/account.html?auth=confirmed` },
  });
  setBusy(form, false);
  if (error) {
    setMessage(authErrorMessage(error), 'error');
    return;
  }
  sessionStorage.setItem('ttm_web_marketing_opt_in', values.get('marketing') ? '1' : '0');
  if (!data.session) {
    setMessage('인증 메일을 보냈습니다. 메일의 인증을 완료한 뒤 이 페이지에서 로그인해 주세요.', 'success');
    return;
  }
  const view = await refreshAccountView();
  if (view === 'complete') goHomeAfterComplete();
});

document.getElementById('identityStart').addEventListener('click', async () => {
  setMessage();
  const button = document.getElementById('identityStart');
  clearIdentityPoll();
  if (!(await hasSession())) {
    showView('login');
    setMessage('로그인 후 본인인증을 진행해 주세요.', 'error');
    return;
  }
  const { data: { session } } = await supabase.auth.getSession();
  if (!hasRequiredConsents(session?.user?.id)) {
    showView('legal');
    setMessage('본인인증 전에 이용약관과 개인정보 처리방침에 동의해 주세요.', 'error');
    return;
  }
  const popup = window.open('about:blank', 'ttmIdentity', 'popup,width=520,height=760');
  if (!popup) {
    setMessage('팝업을 허용한 뒤 다시 시도해 주세요.', 'error');
    return;
  }
  identityPopup = popup;
  renderIdentityPopup(popup, '본인인증 준비 중', '계정 정보를 확인하고 있습니다. 잠시만 기다려 주세요.');
  button.disabled = true;
  try {
    const { data, error } = await supabase.rpc('create_identity_verification_session');
    if (error) throw error;
    if (!data?.state) throw new Error('identity_state_missing');
    await loadProfile();
    const url = new URL(selectedIdentityUrl());
    url.searchParams.set('state', data.state);
    popup.location.href = url.toString();
    setMessage('인증창을 완료하면 자동으로 이 화면에 반영됩니다.', 'success');
    identityStatusTimer = window.setInterval(async () => {
      await confirmIdentityResult('poll');
    }, 2500);
    identityPollTimer = window.setInterval(async () => {
      if (!identityPopup || identityPopup.closed) {
        clearIdentityPoll();
        await confirmIdentityResultWithRetry('popup-closed');
      }
    }, 1200);
  } catch (error) {
    const userMessage = authErrorMessage(error);
    renderIdentityPopup(popup, '본인인증을 시작하지 못했습니다.', userMessage, true);
    setMessage(userMessage, 'error');
  } finally {
    button.disabled = false;
  }
});

document.getElementById('identityRefresh').addEventListener('click', async () => {
  await confirmIdentityResultWithRetry('manual');
});

document.getElementById('legalForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const values = new FormData(form);
  if (!values.get('terms') || !values.get('privacy')) {
    setMessage('필수 약관과 개인정보 처리방침에 동의해 주세요.', 'error');
    return;
  }
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    showView('login');
    setMessage('로그인 후 약관 동의를 진행해 주세요.', 'error');
    return;
  }
  storeConsents(session.user.id, values);
  const profile = await loadProfile();
  if (profile?.phone_verified_at) {
    showView('profile');
    setMessage('약관 동의가 완료되었습니다. 회원 정보를 입력해 가입을 마무리해 주세요.', 'success');
  } else {
    showView('identity');
    setMessage('약관 동의가 완료되었습니다. 본인인증을 진행해 주세요.', 'success');
  }
});

window.addEventListener('message', async (event) => {
  if (event?.data?.type !== 'ttm:identity-result') return;
  if (event.data.ok === false) {
    await confirmIdentityResultWithRetry('message-failed', 2);
    return;
  }
  await confirmIdentityResultWithRetry('message');
});

document.getElementById('profileForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const values = new FormData(form);
  setBusy(form, true);
  setMessage();
  try {
    const { data: { session } } = await supabase.auth.getSession();
    const consents = readStoredConsents(session?.user?.id);
    if (!consents?.terms || !consents?.privacy) {
      showView('legal');
      setMessage('가입 완료 전에 필수 약관에 동의해 주세요.', 'error');
      return;
    }
    const nickname = `${values.get('nickname')}`.trim();
    const { data: moderation, error: moderationError } = await supabase.functions.invoke(
      'text-moderation',
      {
        body: {
          context_type: 'nickname',
          text: nickname,
          target_type: 'user',
          target_id: currentProfile?.id || null,
        },
      },
    );
    if (moderationError) {
      console.warn('nickname moderation skipped', moderationError);
    }
    if (moderation?.allowed === false || moderation?.ok === false) {
      throw new Error(moderation.message || '정책상 사용할 수 없는 표현입니다.');
    }
    const marketing = Boolean(consents.marketing);
    const { data, error } = await supabase.rpc('complete_web_account_onboarding', {
      p_nickname: nickname,
      p_marketing_opt_in: marketing,
      p_terms_accepted: Boolean(consents.terms),
      p_privacy_accepted: Boolean(consents.privacy),
    });
    if (error) throw error;
    if (!data?.ok) {
      const messages = {
        not_authenticated: '로그인 세션이 만료되었습니다. 다시 로그인해 주세요.',
        required_consent_missing: '필수 약관과 개인정보 처리방침에 동의해 주세요.',
        nickname_taken: '이미 사용 중인 닉네임입니다.',
        invalid_nickname: '닉네임은 2~20자로 입력해 주세요.',
        identity_verification_required: '본인인증을 먼저 완료해 주세요.',
        profile_not_found: '계정 프로필을 준비하지 못했습니다. 로그아웃 후 다시 로그인해 주세요.',
      };
      throw new Error(messages[data?.reason] || 'profile_failed');
    }
    sessionStorage.removeItem('ttm_web_marketing_opt_in');
    clearConsents(session?.user?.id);
    goHomeAfterComplete();
  } catch (error) {
    const known = `${error?.message || ''}`;
    setMessage(known.includes('입니다') || known.includes('주세요') ? known : authErrorMessage(error), 'error');
  } finally {
    setBusy(form, false);
  }
});

async function signOutAccount() {
  const { data: { session } } = supabase ? await supabase.auth.getSession() : { data: { session: null } };
  clearConsents(session?.user?.id);
  if (supabase) await supabase.auth.signOut();
  currentProfile = null;
  await refreshAccountView();
}

document.querySelectorAll('[data-account-sign-out]').forEach((button) => {
  button.addEventListener('click', signOutAccount);
});

document.getElementById('accountDelete').addEventListener('click', async () => {
  const ok = window.confirm(
    '계정을 삭제할까요? 프로필 개인정보는 비식별화되고, 다시 로그인할 수 없습니다. 정산, 신고, 분쟁 대응에 필요한 거래 기록은 관련 법령과 정책에 따라 보관될 수 있습니다.',
  );
  if (!ok) return;
  setMessage();
  const button = document.getElementById('accountDelete');
  button.disabled = true;
  try {
    const { data, error } = await supabase.functions.invoke('delete-account');
    if (error) throw error;
    if (!data?.ok) throw new Error(data?.reason || 'delete_failed');
    await supabase.auth.signOut();
    currentProfile = null;
    showView('login');
    setMessage('계정을 삭제했습니다.', 'success');
  } catch (_error) {
    setMessage('계정을 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.', 'error');
  } finally {
    button.disabled = false;
  }
});

async function initialize() {
  try {
    const response = await fetch('/api/auth-config', { headers: { Accept: 'application/json' } });
    const config = await response.json();
    if (!response.ok || !config.ok) throw new Error('auth_config_missing');
    identityUrl = config.identityUrl;
    identityUrls = config.identityUrls || { pass: identityUrl };
    setIdentityMethod(identityUrls.pass ? 'pass' : Object.keys(identityUrls)[0] || 'pass');
    supabase = createClient(config.supabaseUrl, config.publishableKey, {
      auth: { persistSession: true, detectSessionInUrl: true, autoRefreshToken: true },
    });
    supabase.auth.onAuthStateChange((event) => {
      window.setTimeout(() => {
        if (event === 'PASSWORD_RECOVERY') {
          openModal(undefined, false);
          showView('recovery');
          return;
        }
        refreshAccountView();
      }, 0);
    });
    const initialView = await refreshAccountView();
    openModal(undefined, false);
    const params = new URLSearchParams(window.location.search);
    const authAction = params.get('auth');
    const identityAction = params.get('identity');
    if (authAction === 'oauth' || authAction === 'confirmed') {
      const { data: { session } } = await supabase.auth.getSession();
      if (session) {
        if (initialView === 'complete') {
          goHomeAfterComplete();
          return;
        }
        if (authAction === 'confirmed') {
          setMessage('이메일 인증이 완료되었습니다. 본인인증을 진행해 주세요.', 'success');
        }
        window.history.replaceState({}, document.title, window.location.pathname);
        return;
      }
    }
    if (authAction === 'recovery') showView('recovery');
    if (identityAction) {
      await confirmIdentityResultWithRetry('redirect');
      window.history.replaceState({}, document.title, window.location.pathname);
    }
  } catch (_error) {
    navAccountLabel.textContent = '로그인';
    showView('unavailable');
  }
}

initialize();
