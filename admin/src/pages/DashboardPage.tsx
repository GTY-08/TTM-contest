import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { LoadingState } from '../components/LoadingState';
import { MetricCard } from '../components/MetricCard';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate, formatWon, shortId, toText } from '../lib/format';
import { callRpc } from '../lib/supabase';
import type { DashboardMetrics, JsonMap, RpcListResult } from '../types/admin';

export function DashboardPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [requests, setRequests] = useState<JsonMap[]>([]);

  useEffect(() => {
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const [metricData, requestData] = await Promise.all([
          callRpc<DashboardMetrics>('admin_get_dashboard_metrics'),
          callRpc<RpcListResult>('admin_list_requests', {
            p_limit: 8,
            p_offset: 0,
          }),
        ]);
        setMetrics(metricData);
        setRequests(requestData.items ?? []);
      } catch (e) {
        setError(e instanceof Error ? e.message : '데이터를 불러오지 못했습니다.');
      } finally {
        setLoading(false);
      }
    }

    void load();
  }, []);

  if (loading) return <LoadingState />;

  return (
    <section className="page">
      <div className="page-title">
        <h2>대시보드</h2>
        <p>신고, 요청, 사용자 상태를 빠르게 확인합니다.</p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      <div className="metric-grid">
        <MetricCard label="전체 사용자" value={metrics?.total_users} />
        <MetricCard label="오늘 요청" value={metrics?.today_requests} />
        <MetricCard label="진행 중 요청" value={metrics?.matched_requests} tone="success" />
        <MetricCard label="완료 요청" value={metrics?.completed_requests} tone="success" />
        <MetricCard label="취소 요청" value={metrics?.cancelled_requests} tone="danger" />
        <MetricCard label="매칭 실패" value={metrics?.failed_requests} tone="warning" />
        <MetricCard
          label="처리 대기 신고"
          value={Number(metrics?.pending_user_reports ?? 0) + Number(metrics?.pending_message_reports ?? 0)}
          tone="warning"
        />
      </div>
      <div className="section-header">
        <h3>최근 요청</h3>
        <Link to="/requests">전체 보기</Link>
      </div>
      {requests.length === 0 ? (
        <EmptyState />
      ) : (
        <DataTable
          rows={requests}
          columns={[
            {
              key: 'id',
              header: '요청 ID',
              render: (row) => <Link to={`/requests/${row.request_id}`}>{shortId(row.request_id)}</Link>,
            },
            { key: 'desc', header: '설명', render: (row) => toText(row.description) },
            { key: 'status', header: '상태', render: (row) => <StatusBadge status={row.status} /> },
            { key: 'reward', header: '보상', render: (row) => formatWon(row.reward) },
            { key: 'created', header: '생성', render: (row) => formatDate(row.created_at) },
          ]}
        />
      )}
    </section>
  );
}
