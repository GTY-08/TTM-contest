import type { AdminAuthState } from '../types/admin';
import { callRpc, supabase } from './supabase';

const adminAuthRedirectUrl = import.meta.env
  .VITE_ADMIN_AUTH_REDIRECT_URL as string | undefined;

function adminRedirectUrl() {
  const configured = adminAuthRedirectUrl?.trim();
  if (configured) {
    try {
      const parsed = new URL(configured);
      if (parsed.origin === window.location.origin) {
        return configured;
      }
    } catch {
      // Ignore invalid or stale environment values and keep the current admin host.
    }
  }
  return `${window.location.origin}/auth/callback`;
}

export async function loadAdminAuthState(): Promise<AdminAuthState> {
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return {
      loading: false,
      session: null,
      user: null,
      isAdmin: false,
      nickname: '',
    };
  }

  try {
    const isAdmin = await loadAdminFlag();
    const { data: profile } = await supabase
      .from('users')
      .select('nickname')
      .eq('id', session.user.id)
      .maybeSingle();

    return {
      loading: false,
      session,
      user: session.user,
      isAdmin,
      nickname: profile?.nickname ?? session.user.email ?? '관리자',
    };
  } catch {
    await supabase.auth.signOut();
    return {
      loading: false,
      session: null,
      user: null,
      isAdmin: false,
      nickname: '',
    };
  }
}

async function loadAdminFlag(): Promise<boolean> {
  try {
    return await callRpc<boolean>('my_is_admin');
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    if (
      message.includes('my_is_admin') ||
      message.includes('Could not find the function') ||
      message.includes('404')
    ) {
      return await callRpc<boolean>('is_admin');
    }
    throw e;
  }
}

export async function signInWithEmail(email: string, password: string) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw new Error(error.message);
}

export async function signInWithGoogle() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: adminRedirectUrl(),
    },
  });
  if (error) throw new Error(error.message);
}

export async function signOut() {
  await supabase.auth.signOut();
}
