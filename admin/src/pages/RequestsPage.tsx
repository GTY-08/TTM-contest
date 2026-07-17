import { FormEvent, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { Pagination } from '../components/Pagination';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate, formatWon, shortId, toText } from '../lib/format';
import { callRpc } from '../lib/supabase';
import type { JsonMap, RpcListResult } from '../types/admin';

const pageSize = 50;

export function RequestsPage() {
  const [status, setStatus] = useState('');
  const [matchingMode, setMatchingMode] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_requests', {
        p_status: status || null,
        p_search: search || null,
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
        p_matching_mode: matchingMode || null,
      });
      setRows(data.items ?? []);
      setTotal(data.total_count ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : '요청 목록을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    setPage(0);
    void load(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, matchingMode]);

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
        <h2>요청 관리</h2>
        <p>빠른 매칭 요청과 일반 매칭 게시물을 분리해서 확인합니다.</p>
      </div>
      <form className="filters" onSubmit={handleSearch}>
        <select value={matchingMode} onChange={(event) => setMatchingMode(event.target.value)}>
          <option value="">전체 매칭</option>
          <option value="quick">빠른 매칭</option>
          <option value="general">일반 매칭</option>
        </select>
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="">전체 상태</option>
          <option value="open">접수 중</option>
          <option value="matched">매칭됨</option>
          <option value="completed">완료</option>
          <option value="cancelled">취소됨</option>
          <option value="failed">실패</option>
        </select>
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="요청 ID, 제목, 설명, 닉네임 검색"
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
                header: '요청',
                render: (row) => (
                  <Link to={`/requests/${row.request_id}`}>
                    {toText(row.title ?? row.description)}
                    <small>{shortId(row.request_id)}</small>
                  </Link>
                ),
              },
              { key: 'mode', header: '유형', render: (row) => matchModeLabel(row.matching_mode) },
              { key: 'requester', header: '요청자', render: (row) => toText(row.requester_nickname) },
              { key: 'worker', header: '작업자', render: (row) => toText(row.worker_nickname) },
              { key: 'applications', header: '지원자', render: (row) => toText(row.application_count) },
              {
                key: 'reward',
                header: '금액',
                render: (row) =>
                  row.matching_mode === 'general' && (row.reward_min || row.reward_max)
                    ? `${formatWon(row.reward_min)} ~ ${formatWon(row.reward_max)}`
                    : formatWon(row.reward),
              },
              { key: 'status', header: '상태', render: (row) => <StatusBadge status={row.status} /> },
              { key: 'created', header: '생성일', render: (row) => formatDate(row.created_at) },
              { key: 'deadline', header: '마감', render: (row) => formatDate(row.deadline) },
            ]}
          />
          <Pagination page={page} total={total} pageSize={pageSize} onPageChange={handlePage} />
        </>
      )}
    </section>
  );
}

function matchModeLabel(value: unknown): string {
  if (value === 'general') return '일반 매칭';
  if (value === 'quick') return '빠른 매칭';
  return toText(value);
}
