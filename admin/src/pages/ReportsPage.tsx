import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { Pagination } from '../components/Pagination';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate, shortId, toText } from '../lib/format';
import { callRpc } from '../lib/supabase';
import type { JsonMap, RpcListResult } from '../types/admin';

const pageSize = 50;

export function ReportsPage() {
  const [type, setType] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_reports', {
        p_report_type: type || null,
        p_status: status || null,
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
      });
      setRows(data.items ?? []);
      setTotal(data.total_count ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : '신고 목록을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    setPage(0);
    void load(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [type, status]);

  function handlePage(next: number) {
    setPage(next);
    void load(next);
  }

  return (
    <section className="page">
      <div className="page-title">
        <h2>신고 관리</h2>
        <p>사용자 신고, 빠른 매칭 채팅 신고, 일반 지원 채팅 신고를 통합 확인합니다.</p>
      </div>
      <div className="filters">
        <select value={type} onChange={(event) => setType(event.target.value)}>
          <option value="">전체 유형</option>
          <option value="user">사용자 신고</option>
          <option value="message">빠른 매칭 채팅 신고</option>
          <option value="general_message">일반 지원 채팅 신고</option>
        </select>
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="">전체 상태</option>
          <option value="pending">접수 중</option>
          <option value="reviewing">검토 중</option>
          <option value="resolved">처리 완료</option>
          <option value="dismissed">기각</option>
        </select>
      </div>
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
              { key: 'type', header: '유형', render: (row) => reportTypeLabel(row.report_type) },
              {
                key: 'id',
                header: '신고',
                render: (row) => (
                  <Link to={`/reports/${row.report_type}/${row.report_id}`}>
                    {shortId(row.report_id)}
                    <small>{toText(row.description)}</small>
                  </Link>
                ),
              },
              { key: 'category', header: '분류', render: (row) => toText(row.category) },
              { key: 'status', header: '상태', render: (row) => <StatusBadge status={row.status} /> },
              { key: 'reporter', header: '신고자', render: (row) => toText(row.reporter_nickname) },
              { key: 'reported', header: '대상자', render: (row) => toText(row.reported_user_nickname) },
              { key: 'request', header: '요청', render: (row) => shortId(row.request_id) },
              { key: 'created', header: '접수일', render: (row) => formatDate(row.created_at) },
            ]}
          />
          <Pagination page={page} total={total} pageSize={pageSize} onPageChange={handlePage} />
        </>
      )}
    </section>
  );
}

export function reportTypeLabel(value: unknown): string {
  if (value === 'user') return '사용자 신고';
  if (value === 'message') return '빠른 매칭 채팅 신고';
  if (value === 'general_message') return '일반 지원 채팅 신고';
  return toText(value);
}
