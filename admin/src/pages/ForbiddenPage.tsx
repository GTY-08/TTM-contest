import { Link } from 'react-router-dom';

import { signOut } from '../lib/auth';

export function ForbiddenPage() {
  return (
    <div className="login-page">
      <section className="login-panel">
        <h1>접근 권한이 없습니다.</h1>
        <p>현재 계정에는 TTM Admin 권한이 없습니다.</p>
        <button className="primary-button" type="button" onClick={() => void signOut()}>
          로그아웃
        </button>
        <Link to="/login">로그인으로 돌아가기</Link>
      </section>
    </div>
  );
}
