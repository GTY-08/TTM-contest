import { Outlet, useNavigate } from 'react-router-dom';

import { signOut } from '../lib/auth';
import { Sidebar } from './Sidebar';

export function AdminLayout({ nickname }: { nickname: string }) {
  const navigate = useNavigate();

  async function handleLogout() {
    await signOut();
    navigate('/login', { replace: true });
  }

  return (
    <div className="shell">
      <Sidebar onLogout={handleLogout} />
      <main className="main">
        <header className="topbar">
          <div>
            <p className="eyebrow">관리자</p>
            <h1>{nickname}</h1>
          </div>
        </header>
        <Outlet />
      </main>
    </div>
  );
}
