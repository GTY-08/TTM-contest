import { useEffect, useState } from 'react';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { formatDate, formatWon, shortId, toText } from '../lib/format';
import { callRpc } from '../lib/supabase';
import type { JsonMap } from '../types/admin';

type SettlementListResult = {
  ok?: boolean;
  items?: JsonMap[];
  total?: number;
};

const statusOptions = [
  { value: 'requested', label: '지급 대기' },
  { value: 'paid', label: '지급 완료' },
  { value: 'rejected', label: '반려' },
];

export function SettlementsPage() {
  const [status, setStatus] = useState('requested');
  const [loading, setLoading] = useState(true);
  const [submittingId, setSubmittingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [items, setItems] = useState<JsonMap[]>([]);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<SettlementListResult>(
        'admin_list_worker_settlement_requests',
        {
          p_status: status,
          p_limit: 50,
          p_offset: 0,
        },
      );
      setItems(data.items ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : '정산 요청을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, [status]);

  async function markPaid(row: JsonMap) {
    const id = String(row.id ?? '');
    if (!id) return;
    const ok = window.confirm(
      `${formatWon(row.net_amount)}을 실제 계좌로 송금 완료했습니까?\n완료 처리 후 작업자 앱에 지급 완료로 표시됩니다.`,
    );
    if (!ok) return;

    setSubmittingId(id);
    setError(null);
    try {
      await callRpc('admin_mark_worker_settlement_paid', {
        p_settlement_request_id: id,
        p_admin_note: '관리자 수동 지급 완료',
      });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : '지급 완료 처리에 실패했습니다.');
    } finally {
      setSubmittingId(null);
    }
  }

  async function reject(row: JsonMap) {
    const id = String(row.id ?? '');
    if (!id) return;
    const note = window.prompt('반려 사유를 입력하세요.');
    if (!note?.trim()) return;

    setSubmittingId(id);
    setError(null);
    try {
      await callRpc('admin_reject_worker_settlement_request', {
        p_settlement_request_id: id,
        p_admin_note: note.trim(),
      });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : '정산 요청 반려에 실패했습니다.');
    } finally {
      setSubmittingId(null);
    }
  }

  if (loading) return <LoadingState />;

  return (
    <section className="page">
      <div className="page-title">
        <h2>정산 요청</h2>
        <p>지급대행 연동 전까지 작업자 정산 요청을 확인하고 수동 지급 완료 처리합니다.</p>
      </div>

      <div className="toolbar">
        <label>
          상태
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            {statusOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <button type="button" onClick={() => void load()}>
          새로고침
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {items.length === 0 ? (
        <EmptyState />
      ) : (
        <DataTable
          rows={items}
          columns={[
            { key: 'id', header: '요청 ID', render: (row) => shortId(row.id) },
            { key: 'worker', header: '작업자', render: (row) => toText(row.worker_nickname) },
            { key: 'amount', header: '정산액', render: (row) => formatWon(row.net_amount) },
            { key: 'fee', header: '수수료', render: (row) => formatWon(row.fee_amount) },
            { key: 'count', header: '건수', render: (row) => toText(row.request_count) },
            {
              key: 'account',
              header: '지급 계좌',
              render: (row) =>
                `${toText(row.bank_name)} ${toText(row.account_number_masked)} / ${toText(row.account_holder)}`,
            },
            { key: 'requested', header: '요청일', render: (row) => formatDate(row.requested_at) },
            {
              key: 'actions',
              header: '처리',
              render: (row) =>
                row.status === 'requested' ? (
                  <div className="row-actions">
                    <button
                      type="button"
                      disabled={submittingId === row.id}
                      onClick={() => void markPaid(row)}
                    >
                      지급 완료
                    </button>
                    <button
                      type="button"
                      className="danger"
                      disabled={submittingId === row.id}
                      onClick={() => void reject(row)}
                    >
                      반려
                    </button>
                  </div>
                ) : (
                  toText(row.status)
                ),
            },
          ]}
        />
      )}
    </section>
  );
}
