import { useEffect, useState } from 'react';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { Pagination } from '../components/Pagination';
import { formatDate, shortId, toText } from '../lib/format';
import { callRpc } from '../lib/supabase';
import type { JsonMap, RpcListResult } from '../types/admin';

const pageSize = 100;

export function AuditLogsPage() {
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_audit_logs', {
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
      });
      setRows(data.items ?? []);
      setTotal(data.total_count ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : '감사 로그를 불러오지 못했습니다.');
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
        <h2>감사 로그</h2>
        <p>관리자 상세 조회, 위치 공개, 신고 처리, 제한 변경 이력을 확인합니다.</p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {loading ? <LoadingState /> : rows.length === 0 ? <EmptyState /> : (
        <>
          <DataTable
            rows={rows}
            columns={[
              { key: 'admin', header: '관리자', render: (row) => toText(row.admin_nickname) },
              { key: 'action', header: '액션', render: (row) => toText(row.action_type) },
              { key: 'user', header: '대상 사용자', render: (row) => shortId(row.target_user_id) },
              { key: 'request', header: '대상 요청', render: (row) => shortId(row.target_request_id) },
              { key: 'time', header: '시각', render: (row) => formatDate(row.created_at) },
              { key: 'metadata', header: '메타데이터', render: (row) => <pre>{JSON.stringify(row.metadata ?? {}, null, 2)}</pre> },
            ]}
          />
          <Pagination page={page} total={total} pageSize={pageSize} onPageChange={handlePage} />
        </>
      )}
    </section>
  );
}
