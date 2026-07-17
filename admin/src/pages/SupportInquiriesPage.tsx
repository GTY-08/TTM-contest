import { useEffect, useMemo, useState } from 'react';

import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { Pagination } from '../components/Pagination';
import { formatDate, shortId, toText } from '../lib/format';
import { callRpc, supabase } from '../lib/supabase';
import type { JsonMap, RpcListResult } from '../types/admin';

const pageSize = 50;
const supportApiUrl =
  (import.meta.env.VITE_SUPPORT_API_URL as string | undefined)?.trim() ||
  'https://www.ttmttm.com/api/support-reply';

const statusLabels: Record<string, string> = {
  open: '접수',
  reviewing: '검토 중',
  resolved: '답변 완료',
  closed: '종료',
};

const categoryLabels: Record<string, string> = {
  account: '계정',
  identity: '본인확인',
  app: '앱 오류',
  payment: '지갑·결제',
  other: '기타',
};

export function SupportInquiriesPage() {
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState('');
  const [reply, setReply] = useState('');
  const [sending, setSending] = useState(false);
  const [notice, setNotice] = useState('');

  const selected = useMemo(
    () => rows.find((row) => String(row.id) === selectedId) ?? null,
    [rows, selectedId],
  );

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_web_support_inquiries', {
        p_status: status || null,
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
      });
      const items = data.items ?? [];
      setRows(items);
      setTotal(data.total_count ?? 0);
      const queryId = new URLSearchParams(window.location.search).get('inquiry');
      const nextSelected = items.find((row) => String(row.id) === queryId) ?? items[0];
      if (nextSelected) setSelectedId(String(nextSelected.id));
    } catch (e) {
      setError(e instanceof Error ? e.message : '문의 목록을 불러오지 못했습니다.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    setPage(0);
    void load(0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);

  async function sendReply() {
    if (!selected || reply.trim().length < 2) return;
    setSending(true);
    setError(null);
    setNotice('');
    try {
      const { data } = await supabase.auth.getSession();
      const token = data.session?.access_token;
      if (!token) throw new Error('관리자 세션이 만료되었습니다. 다시 로그인해 주세요.');
      const response = await fetch(supportApiUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ inquiryId: selected.id, reply: reply.trim() }),
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok || !payload.ok) {
        throw new Error(payload.reason || '답변을 발송하지 못했습니다.');
      }
      setReply('');
      setNotice('브랜드 답변 메일을 발송하고 문의를 답변 완료로 변경했습니다.');
      await load(page);
    } catch (e) {
      setError(e instanceof Error ? e.message : '답변을 발송하지 못했습니다.');
    } finally {
      setSending(false);
    }
  }

  return (
    <section className="page">
      <div className="page-title">
        <h2>고객 문의</h2>
        <p>웹 고객센터 문의를 확인하고 틈틈 디자인이 적용된 답변 메일을 보냅니다.</p>
      </div>
      <div className="filters">
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="">전체 상태</option>
          <option value="open">접수</option>
          <option value="reviewing">검토 중</option>
          <option value="resolved">답변 완료</option>
          <option value="closed">종료</option>
        </select>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {notice ? <p className="success">{notice}</p> : null}
      {loading ? (
        <LoadingState />
      ) : rows.length === 0 ? (
        <EmptyState />
      ) : (
        <>
          <div className="support-inbox">
            <div className="support-inbox-list">
              {rows.map((row) => (
                <button
                  className={`support-inquiry-item ${String(row.id) === selectedId ? 'active' : ''}`}
                  key={String(row.id)}
                  type="button"
                  onClick={() => {
                    setSelectedId(String(row.id));
                    setReply('');
                    setNotice('');
                  }}
                >
                  <span>{categoryLabels[toText(row.category)] ?? toText(row.category)}</span>
                  <strong>{toText(row.subject)}</strong>
                  <small>{toText(row.email)} · {formatDate(row.created_at)}</small>
                  <em>{statusLabels[toText(row.status)] ?? toText(row.status)}</em>
                </button>
              ))}
            </div>
            {selected ? (
              <article className="support-reply-panel">
                <div className="support-reply-meta">
                  <span>접수번호 {shortId(selected.id)}</span>
                  <span>{toText(selected.email)}</span>
                </div>
                <h3>{toText(selected.subject)}</h3>
                <div className="support-original-message">{toText(selected.message)}</div>
                {selected.admin_note ? (
                  <div className="support-previous-reply">
                    <strong>최근 답변</strong>
                    <p>{toText(selected.admin_note)}</p>
                  </div>
                ) : null}
                <label className="support-reply-field">
                  <span>답변 내용</span>
                  <textarea
                    value={reply}
                    onChange={(event) => setReply(event.target.value)}
                    maxLength={4000}
                    placeholder="사용자에게 전달할 답변을 입력하세요."
                  />
                </label>
                <div className="action-row">
                  <button
                    className="primary"
                    type="button"
                    disabled={sending || reply.trim().length < 2}
                    onClick={() => void sendReply()}
                  >
                    {sending ? '발송 중…' : '브랜드 답변 메일 보내기'}
                  </button>
                </div>
              </article>
            ) : null}
          </div>
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
