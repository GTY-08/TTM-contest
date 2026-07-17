import { FormEvent, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { Pagination } from '../components/Pagination';
import { formatDate, formatNumber, shortId, toText } from '../lib/format';
import { callRpc } from '../lib/supabase';
import type { JsonMap, RpcListResult } from '../types/admin';

const pageSize = 50;

export function UsersPage() {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_users', {
        p_search: search || null,
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
      });
      setRows(data.items ?? []);
      setTotal(data.total_count ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : '사용자 목록을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function handleSearch(event: FormEvent) {
    event.preventDefault();
    setPage(0);
    void load(0);
  }

  function handlePage(next: number) {
    setPage(next);
    void load(next);
  }

  return (
    <section className="page">
      <div className="page-title">
        <h2>사용자 관리</h2>
        <p>사용자 상태와 활성 제재를 확인합니다.</p>
      </div>
      <form className="filters" onSubmit={handleSearch}>
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="닉네임, 이메일, 전화번호, UUID"
        />
        <button type="submit">검색</button>
      </form>
      {error ? <p className="error">{error}</p> : null}
      {loading ? (
        <LoadingState />
      ) : rows.length === 0 ? (
        <EmptyState />
      ) : (
        <>
          <DataTable
            rows={rows}
            columns={[
              {
                key: 'id',
                header: '사용자',
                render: (row) => (
                  <Link to={`/users/${row.user_id}`}>
                    {toText(row.nickname)}
                    <small>{shortId(row.user_id)}</small>
                  </Link>
                ),
              },
              { key: 'email', header: '이메일', render: (row) => toText(row.email) },
              { key: 'phone', header: '전화번호', render: (row) => toText(row.phone) },
              {
                key: 'rating',
                header: '평점',
                render: (row) => `${formatNumber(row.rating)} (${formatNumber(row.rating_count)})`,
              },
              {
                key: 'trust',
                header: '신뢰/악용',
                render: (row) => `${formatNumber(row.trust_score)} / ${formatNumber(row.abuse_score)}`,
              },
              {
                key: 'cancel',
                header: '취소',
                render: (row) =>
                  `${formatNumber(row.requester_cancel_count)} / ${formatNumber(row.worker_cancel_count)}`,
              },
              {
                key: 'restrict',
                header: '활성 제재',
                render: (row) => (
                  <Link to={`/users/${row.user_id}`}>{formatNumber(row.active_restriction_count)}</Link>
                ),
              },
              { key: 'created', header: '가입일', render: (row) => formatDate(row.created_at) },
            ]}
          />
          <Pagination page={page} total={total} pageSize={pageSize} onPageChange={handlePage} />
        </>
      )}
    </section>
  );
}
