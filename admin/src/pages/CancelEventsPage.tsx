import { useEffect, useState } from 'react';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { Pagination } from '../components/Pagination';
import { formatDate, formatNumber, shortId, toText } from '../lib/format';
import { callRpc } from '../lib/supabase';
import type { JsonMap, RpcListResult } from '../types/admin';

const pageSize = 50;

export function CancelEventsPage() {
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_cancel_events', {
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
      });
      setRows(data.items ?? []);
      setTotal(data.total_count ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : '취소 기록을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function handlePage(next: number) {
    setPage(next);
    void load(next);
  }

  return (
    <section className="page">
      <div className="page-title">
        <h2>취소 기록</h2>
        <p>취소 판단 근거와 페널티 여부를 확인합니다.</p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {loading ? <LoadingState /> : rows.length === 0 ? <EmptyState /> : (
        <>
          <DataTable
            rows={rows}
            columns={[
              { key: 'by', header: '취소자', render: (row) => shortId(row.cancelled_by) },
              { key: 'role', header: '역할', render: (row) => toText(row.cancelled_by_role) },
              { key: 'reason', header: '사유', render: (row) => toText(row.cancel_reason) },
              { key: 'elapsed', header: '경과', render: (row) => `${formatNumber(row.matched_elapsed_seconds)}초` },
              { key: 'score', header: '책임 점수', render: (row) => `${formatNumber(row.requester_responsibility_score)} / ${formatNumber(row.worker_responsibility_score)}` },
              { key: 'abuse', header: '악용', render: (row) => formatNumber(row.abuse_pattern_score) },
              { key: 'decision', header: '판정', render: (row) => toText(row.decision) },
              { key: 'penalty', header: '페널티', render: (row) => row.penalty_applied ? '적용' : '없음' },
              { key: 'created', header: '시각', render: (row) => formatDate(row.cancelled_at) },
            ]}
          />
          <Pagination page={page} total={total} pageSize={pageSize} onPageChange={handlePage} />
        </>
      )}
    </section>
  );
}
