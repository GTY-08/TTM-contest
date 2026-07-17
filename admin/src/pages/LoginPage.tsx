import { FormEvent, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { loadAdminAuthState, signInWithEmail, signInWithGoogle } from '../lib/auth';

export function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void loadAdminAuthState().then((auth) => {
      if (auth.session && auth.isAdmin) navigate('/', { replace: true });
      if (auth.session && !auth.isAdmin) navigate('/forbidden', { replace: true });
    });
  }, [navigate]);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await signInWithEmail(email, password);
      const auth = await loadAdminAuthState();
      navigate(auth.isAdmin ? '/' : '/forbidden', { replace: true });
    } catch (e) {
      setError(e instanceof Error ? e.message : '로그인에 실패했습니다.');
    } finally {
      setBusy(false);
    }
  }

  async function handleGoogleLogin() {
    setBusy(true);
    setError(null);
    try {
      await signInWithGoogle();
    } catch (e) {
      setBusy(false);
      setError(e instanceof Error ? e.message : 'Google 로그인에 실패했습니다.');
    }
  }

  return (
    <div className="login-page">
      <form className="login-panel" onSubmit={handleSubmit}>
        <div className="brand compact">
          <span className="brand-mark">TTM</span>
          <div>
            <strong>TTM Admin</strong>
            <small>관리자 로그인</small>
          </div>
        </div>
        <button
          className="google-button"
          type="button"
          onClick={() => void handleGoogleLogin()}
          disabled={busy}
        >
          Google로 로그인
        </button>
        <div className="login-divider">
          <span>또는 이메일 비밀번호</span>
        </div>
        <label>
          이메일
          <input
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </label>
        <label>
          비밀번호
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </label>
        {error ? <p className="error">{error}</p> : null}
        <button className="primary-button" type="submit" disabled={busy}>
          {busy ? '확인 중' : '로그인'}
        </button>
      </form>
    </div>
  );
}
