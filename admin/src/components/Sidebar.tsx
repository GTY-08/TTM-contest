import { NavLink } from 'react-router-dom';

const navItems = [
  { to: '/', label: '대시보드', end: true },
  { to: '/exercise-venues', label: '레이드 장소 관리' },
  { to: '/requests', label: '요청 관리' },
  { to: '/users', label: '사용자 관리' },
  { to: '/restrictions', label: '제재 관리' },
  { to: '/settlements', label: '정산 요청' },
  { to: '/support', label: '고객 문의' },
  { to: '/reports', label: '신고 관리' },
  { to: '/proof-incidents', label: '작업 인증 사건' },
  { to: '/cancellations', label: '취소 기록' },
  { to: '/audit', label: '감사 로그' },
];

export function Sidebar({ onLogout }: { onLogout: () => void }) {
  return (
    <aside className="sidebar">
      <div className="brand">
        <span className="brand-mark">TTM</span>
        <div>
          <strong>TTM Admin</strong>
          <small>운영 백오피스</small>
        </div>
      </div>
      <nav className="nav">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>
      <button className="logout-button" type="button" onClick={onLogout}>
        로그아웃
      </button>
    </aside>
  );
}
