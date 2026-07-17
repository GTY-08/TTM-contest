import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { LoadingState } from '../components/LoadingState';
import { ChatTranscript, FieldGrid, KeyValueList, RecordList } from '../components/ReadableData';
import { StatusBadge } from '../components/StatusBadge';
import { callRpc } from '../lib/supabase';
import type { JsonMap } from '../types/admin';

export function RequestDetailPage() {
  const { id } = useParams();
  const [detail, setDetail] = useState<JsonMap | null>(null);
  const [locations, setLocations] = useState<JsonMap | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      if (!id) return;
      setLoading(true);
      setError(null);
      try {
        const data = await callRpc<{ detail: JsonMap }>('admin_get_request_detail', {
          p_request_id: id,
        });
        setDetail(data.detail);
      } catch (e) {
        setError(e instanceof Error ? e.message : '요청 상세를 불러오지 못했습니다.');
      } finally {
        setLoading(false);
      }
    }

    void load();
  }, [id]);

  async function revealLocations() {
    if (!id) return;
    const reason = window.prompt('위치정보 확인 사유를 입력하세요.');
    if (!reason?.trim()) return;
    const data = await callRpc<{ locations: JsonMap }>('admin_get_request_locations', {
      p_request_id: id,
      p_reason: reason,
    });
    setLocations(data.locations);
  }

  if (loading) return <LoadingState />;
  const request = detail?.request as JsonMap | undefined;

  return (
    <section className="page">
      <div className="page-title">
        <Link to="/requests">요청 목록</Link>
        <h2>요청 상세</h2>
        <p>{id}</p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {request ? (
        <div className="detail-grid">
          <article className="panel">
            <h3>기본 정보</h3>
            <FieldGrid
              fields={[
                { label: '상태', value: <StatusBadge status={request.status} /> },
                { label: '매칭 유형', value: request.matching_mode === 'general' ? '일반 매칭' : '빠른 매칭' },
                { label: '제목', value: request.title },
                { label: '설명', value: request.description },
                { label: '보상', value: request.reward, type: 'won' },
                { label: '최소 보상', value: request.reward_min, type: 'won' },
                { label: '최대 보상', value: request.reward_max, type: 'won' },
                { label: '협의 금액', value: request.negotiated_reward, type: 'won' },
                { label: '결제 상태', value: paymentStatusLabel(request.general_payment_status) },
                { label: '생성일', value: request.created_at, type: 'date' },
                { label: '마감', value: request.deadline, type: 'date' },
                { label: '매칭일', value: request.matched_at, type: 'date' },
                { label: '완료일', value: request.completed_at, type: 'date' },
              ]}
            />
            <button type="button" onClick={revealLocations}>
              위치정보 확인
            </button>
            {locations ? <KeyValueList title="위치정보" data={locations} /> : null}
          </article>

          <article className="panel">
            <h3>참여자</h3>
            <KeyValueList title="요청자" data={detail?.requester as JsonMap | undefined} />
            <KeyValueList title="작업자" data={detail?.worker as JsonMap | undefined} />
          </article>

          <article className="panel wide">
            <h3>일반 매칭 게시물</h3>
            <RecordList title="이미지" rows={detail?.general_post_images ?? []} />
            <RecordList title="댓글" rows={detail?.general_post_comments ?? []} />
            <RecordList title="지원자" rows={detail?.general_applications ?? []} />
          </article>

          <article className="panel wide">
            <h3>빠른 매칭 채팅</h3>
            <ChatTranscript rows={detail?.messages ?? []} />
          </article>

          <article className="panel wide">
            <h3>후기, 취소, 신고</h3>
            <RecordList title="후기" rows={detail?.reviews ?? []} />
            <RecordList title="취소 이력" rows={detail?.cancel_events ?? []} />
            <RecordList title="사용자 신고" rows={detail?.user_reports ?? []} />
            <RecordList title="빠른 매칭 채팅 신고" rows={detail?.message_reports ?? []} />
            <RecordList title="일반 지원 채팅 신고" rows={detail?.general_message_reports ?? []} />
          </article>
        </div>
      ) : null}
    </section>
  );
}

function paymentStatusLabel(value: unknown): string {
  if (value === 'pending') return '결제 대기';
  if (value === 'paid') return '결제 완료';
  if (value === 'not_required') return '결제 불필요';
  return String(value ?? '-');
}
