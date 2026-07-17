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

export function TaskProofIncidentsPage() {
  const [status, setStatus] = useState('pending');
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_task_proof_incidents', {
        p_status: status || null,
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
      });
      setRows(data.items ?? []);
      setTotal(data.total_count ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : '인증 사건을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    setPage(0);
    void load(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  return (
    <section className="page">
      <div className="page-title">
        <h2>작업 인증 사건</h2>
        <p>요청자 반려와 서버가 확인한 인증 기한 누락을 검토합니다.</p>
      </div>
      <div className="filters">
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="pending">검토 대기</option>
          <option value="resolved">처리 완료</option>
          <option value="dismissed">기각</option>
          <option value="">전체</option>
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
              {
                key: 'incident',
                header: '사건',
                render: (row) => (
                  <Link to={`/proof-incidents/${row.incident_id}`}>
                    {shortId(row.incident_id)}
                    <small>{incidentTypeLabel(row.incident_type)}</small>
                  </Link>
                ),
              },
              { key: 'source', header: '발생 경로', render: (row) => sourceLabel(row.source) },
              { key: 'reason', header: '사유', render: (row) => toText(row.reason) },
              { key: 'worker', header: '작업자', render: (row) => toText(row.worker_nickname) },
              { key: 'request', header: '요청', render: (row) => toText(row.request_title) || shortId(row.request_id) },
              { key: 'status', header: '상태', render: (row) => <StatusBadge status={row.status} /> },
              { key: 'created', header: '발생일', render: (row) => formatDate(row.created_at) },
            ]}
          />
          <Pagination
            page={page}
            total={total}
            pageSize={pageSize}
            onPageChange={(next) => {
              setPage(next);
              void load(next);
            }}
          />
        </>
      )}
    </section>
  );
}

export function sourceLabel(value: unknown): string {
  if (value === 'requester_rejection') return '요청자 반려';
  if (value === 'deadline_missed') return '자동 기한 감지';
  return toText(value);
}

export function incidentTypeLabel(value: unknown): string {
  const labels: Record<string, string> = {
    proof_rejected: '인증 사진 반려',
    waiting_checkin_missed: '대기 인증 누락',
    care_checkin_missed: '돌봄 중간 인증 누락',
  };
  return labels[String(value ?? '')] ?? toText(value);
}
