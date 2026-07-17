import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const publishableKey = import.meta.env
  .VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;

if (!supabaseUrl || !publishableKey) {
  console.warn('TTM Admin: Supabase 환경 변수가 설정되지 않았습니다.');
}

export const supabase = createClient(supabaseUrl ?? '', publishableKey ?? '', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

export async function callRpc<T = unknown>(
  name: string,
  params?: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await supabase.rpc(name, params ?? {});
  if (error) {
    throw new Error(error.message);
  }
  return data as T;
}
