import { FormEvent, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { Pagination } from '../components/Pagination';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate, shortId, toText } from '../lib/format';
import {
  restrictionStatusLabel,
  restrictionStatusOptions,
  restrictionTypeLabel,
} from '../lib/restrictions';
import { callRpc } from '../lib/supabase';
import type { JsonMap, RpcListResult } from '../types/admin';

const pageSize = 50;

export function RestrictionsPage() {
  const [status, setStatus] = useState('active');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<JsonMap[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function load(nextPage = page) {
    setLoading(true);
    setError(null);
    try {
      const data = await callRpc<RpcListResult>('admin_list_user_restrictions', {
        p_status: status,
        p_search: search || null,
        p_limit: pageSize,
        p_offset: nextPage * pageSize,
      });
      setRows(data.items ?? []);
      setTotal(data.total_count ?? 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : '제재 목록을 불러오지 못했습니다.');
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

  async function revokeRestriction(row: JsonMap) {
    const restrictionId = String(row.restriction_id ?? '');
    if (!restrictionId) {
      setError('해제할 제재 ID가 없습니다.');
      return;
    }

    const reason = window.prompt('해제 사유를 입력하세요. 비워도 해제할 수 있습니다.');
    if (reason === null) return;
    if (!window.confirm(`${toText(row.nickname)} 사용자의 제재를 해제하시겠습니까?`)) return;

    setSavingId(restrictionId);
    setError(null);
    setNotice(null);
    try {
      await callRpc('admin_revoke_user_restriction', {
        p_restriction_id: restrictionId,
        p_reason: reason.trim() ? reason.trim() : null,
      });
      setNotice('제재를 해제했습니다.');
      await load(page);
    } catch (e) {
      setError(e instanceof Error ? e.message : '제재 해제에 실패했습니다.');
    } finally {
      setSavingId(null);
    }
  }

  return (
    <section className="page">
      <div className="page-title">
        <h2>제재 관리</h2>
        <p>사용자 제재를 검색하고 상태별로 확인하며 즉시 해제합니다.</p>
      </div>

      <form className="filters" onSubmit={handleSearch}>
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          {restrictionStatusOptions.map((item) => (
            <option key={item.value} value={item.value}>
              {item.label}
            </option>
          ))}
        </select>
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="닉네임, 이메일, 전화번호, UUID, 사유"
        />
        <button type="submit">검색</button>
      </form>

      {error ? <p className="error">{error}</p> : null}
      {notice ? <p className="success-message">{notice}</p> : null}

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
                key: 'user',
                header: '사용자',
                render: (row) => (
                  <Link to={`/users/${row.user_id}`}>
                    {toText(row.nickname)}
                    <small>{shortId(row.user_id)}</small>
                  </Link>
                ),
              },
              {
                key: 'type',
                header: '제재',
                render: (row) => restrictionTypeLabel(row.restriction_type),
              },
              {
                key: 'status',
                header: '상태',
                render: (row) => (
                  <StatusBadge status={restrictionStatusLabel(row.effective_status)} />
                ),
              },
              { key: 'reason', header: '사유', render: (row) => toText(row.reason) },
              { key: 'created', header: '생성', render: (row) => formatDate(row.created_at) },
              { key: 'ends', header: '종료', render: (row) => formatDate(row.ends_at) },
              { key: 'revoked', header: '해제', render: (row) => formatDate(row.revoked_at) },
              {
                key: 'action',
                header: '처리',
                render: (row) =>
                  row.effective_status === 'active' ? (
                    <button
                      type="button"
                      disabled={savingId === row.restriction_id}
                      onClick={() => void revokeRestriction(row)}
                    >
                      {savingId === row.restriction_id ? '처리 중' : '해제'}
                    </button>
                  ) : (
                    '-'
                  ),
              },
            ]}
          />
          <Pagination page={page} total={total} pageSize={pageSize} onPageChange={handlePage} />
        </>
      )}
    </section>
  );
}
