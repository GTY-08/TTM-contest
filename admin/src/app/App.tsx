import { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';

import { AdminLayout } from '../components/AdminLayout';
import { LoadingState } from '../components/LoadingState';
import { loadAdminAuthState } from '../lib/auth';
import { supabase } from '../lib/supabase';
import type { AdminAuthState } from '../types/admin';

const initialAuth: AdminAuthState = {
  loading: true,
  session: null,
  user: null,
  isAdmin: false,
  nickname: '',
};

export function ProtectedAdminApp() {
  const [auth, setAuth] = useState<AdminAuthState>(initialAuth);

  useEffect(() => {
    let active = true;

    async function load() {
      const next = await loadAdminAuthState();
      if (active) setAuth(next);
    }

    void load();
    const { data } = supabase.auth.onAuthStateChange(() => {
      void load();
    });

    return () => {
      active = false;
      data.subscription.unsubscribe();
    };
  }, []);

  if (auth.loading) return <LoadingState message="세션을 확인하는 중입니다." />;
  if (!auth.session) return <Navigate to="/login" replace />;
  if (!auth.isAdmin) return <Navigate to="/forbidden" replace />;

  return <AdminLayout nickname={auth.nickname} />;
}
