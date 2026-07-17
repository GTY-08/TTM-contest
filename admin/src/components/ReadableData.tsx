import { isValidElement, type ReactNode } from 'react';
import { Link } from 'react-router-dom';

import { formatDate, formatNumber, formatWon, shortId, toText } from '../lib/format';
import { restrictionStatusLabel, restrictionTypeLabel } from '../lib/restrictions';
import type { JsonMap } from '../types/admin';

type Field = {
  label: string;
  value: unknown;
  type?: 'date' | 'won' | 'id' | 'status' | 'number';
  href?: string;
};

const hiddenKeys = new Set([
  'id',
  'request_id',
  'user_id',
  'requester_id',
  'worker_id',
  'author_id',
  'sender_id',
  'reporter_id',
  'reported_user_id',
  'reviewed_by',
  'created_by',
  'revoked_by',
  'application_id',
  'message_id',
  'profile_image_url',
  'avatar_url',
  'storage_path',
  'geo',
  'requester_live_geo',
  'worker_live_geo',
  'total_count',
  'verified_ci_hash',
  'bank_account',
  'current_stage',
  'max_search_radius_m',
  'sort_order',
]);

const keyOrder = [
  'nickname',
  'requester_nickname',
  'worker_nickname',
  'author_nickname',
  'sender_nickname',
  'reporter_nickname',
  'reported_user_nickname',
  'title',
  'description',
  'content',
  'message_snapshot',
  'category',
  'status',
  'restriction_type',
  'matching_mode',
  'payment_flow',
  'general_payment_status',
  'reward',
  'reward_min',
  'reward_max',
  'negotiated_reward',
  'application_count',
  'message_count',
  'rating',
  'rating_count',
  'email',
  'phone',
  'birth_year',
  'reason',
  'admin_note',
  'created_at',
  'updated_at',
  'matched_at',
  'completed_at',
  'cancelled_at',
  'deadline',
  'starts_at',
  'ends_at',
  'revoked_at',
  'reviewed_at',
];

export function FieldGrid({ fields }: { fields: Field[] }) {
  const visible = fields.filter((field) => {
    const value = field.value;
    return value !== null && value !== undefined && value !== '';
  });

  if (visible.length === 0) return <p className="muted">표시할 정보가 없습니다.</p>;

  return (
    <dl className="field-grid">
      {visible.map((field) => (
        <FieldRow key={field.label} field={field} />
      ))}
    </dl>
  );
}

function FieldRow({ field }: { field: Field }) {
  const content = renderValue(field);
  return (
    <>
      <dt>{field.label}</dt>
      <dd>{field.href ? <Link to={field.href}>{content}</Link> : content}</dd>
    </>
  );
}

function renderValue(field: Field) {
  if (isValidElement(field.value)) return field.value;
  if (field.type === 'date') return formatDate(field.value);
  if (field.type === 'won') return formatWon(field.value);
  if (field.type === 'id') return shortId(field.value);
  if (field.type === 'number') return formatNumber(field.value);
  return toText(field.value);
}

export function KeyValueList({ title, data }: { title?: string; data: JsonMap | null | undefined }) {
  if (!data) return <p className="muted">정보가 없습니다.</p>;
  const entries = visibleEntries(data);
  if (entries.length === 0) return <p className="muted">표시할 정보가 없습니다.</p>;

  return (
    <div className="kv-card">
      {title ? <h4>{title}</h4> : null}
      <dl className="field-grid">
        {entries.map(([key, value]) => (
          <FieldRow key={key} field={{ label: labelForKey(key), value: formatSmartValue(key, value) }} />
        ))}
      </dl>
    </div>
  );
}

export function RecordList({
  title,
  rows,
  empty = '기록이 없습니다.',
}: {
  title?: string;
  rows: unknown;
  empty?: string;
}) {
  const items = Array.isArray(rows) ? (rows as JsonMap[]) : [];
  if (items.length === 0) return <p className="muted">{empty}</p>;

  return (
    <div className="record-list">
      {title ? <h4>{title}</h4> : null}
      {items.map((item, index) => (
        <div className="record-card" key={String(item.id ?? item.message_id ?? index)}>
          <KeyValueList data={item} />
        </div>
      ))}
    </div>
  );
}

export function ChatTranscript({ rows }: { rows: unknown }) {
  const messages = Array.isArray(rows) ? (rows as JsonMap[]) : [];
  if (messages.length === 0) return <p className="muted">대화 내용이 없습니다.</p>;

  return (
    <div className="chat-transcript">
      {messages.map((message, index) => (
        <article className="chat-line" key={String(message.id ?? index)}>
          <div className="chat-meta">
            <strong>{toText(message.sender_nickname ?? message.sender_id)}</strong>
            <span>{formatDate(message.created_at)}</span>
          </div>
          <p>{toText(message.content)}</p>
          {message.attachment_url ? (
            <a href={String(message.attachment_url)} target="_blank" rel="noreferrer">
              첨부 열기
            </a>
          ) : null}
          {message.deleted_at ? <small>삭제됨: {formatDate(message.deleted_at)}</small> : null}
        </article>
      ))}
    </div>
  );
}

function visibleEntries(data: JsonMap): Array<[string, unknown]> {
  return Object.entries(data)
    .filter(([key, value]) => isVisibleEntry(key, value))
    .sort(([a], [b]) => entryRank(a) - entryRank(b) || a.localeCompare(b));
}

function isVisibleEntry(key: string, value: unknown): boolean {
  if (hiddenKeys.has(key)) return false;
  if (value === null || value === undefined || value === '') return false;
  if (Array.isArray(value) && value.length === 0) return false;
  if (typeof value === 'object' && !Array.isArray(value) && Object.keys(value as object).length === 0) return false;
  return true;
}

function entryRank(key: string): number {
  const index = keyOrder.indexOf(key);
  return index === -1 ? keyOrder.length : index;
}

function labelForKey(key: string): string {
  const labels: Record<string, string> = {
    nickname: '닉네임',
    requester_nickname: '요청자',
    worker_nickname: '작업자',
    author_nickname: '작성자',
    sender_nickname: '보낸 사람',
    reporter_nickname: '신고자',
    reported_user_nickname: '대상자',
    email: '이메일',
    phone: '전화번호',
    birth_year: '출생연도',
    title: '제목',
    description: '설명',
    content: '내용',
    message_snapshot: '신고 당시 메시지',
    status: '상태',
    restriction_type: '제재 유형',
    category: '분류',
    reason: '사유',
    admin_note: '관리자 메모',
    reward: '보상',
    reward_min: '최소 보상',
    reward_max: '최대 보상',
    negotiated_reward: '협의 금액',
    matching_mode: '매칭 유형',
    payment_flow: '결제 방식',
    general_payment_status: '일반 매칭 결제',
    application_count: '지원자 수',
    message_count: '메시지 수',
    rating: '평점',
    rating_count: '리뷰 수',
    created_at: '생성일',
    updated_at: '수정일',
    matched_at: '매칭일',
    completed_at: '완료일',
    cancelled_at: '취소일',
    deadline: '마감',
    reviewed_at: '검토일',
    starts_at: '시작일',
    ends_at: '종료일',
    revoked_at: '해제일',
  };
  return labels[key] ?? key.replaceAll('_', ' ');
}

function formatSmartValue(key: string, value: unknown): ReactNode {
  if (value == null || value === '') return '-';
  if (key.endsWith('_at') || key === 'deadline' || key === 'starts_at' || key === 'ends_at') return formatDate(value);
  if (key.includes('reward') || key === 'amount') return formatWon(value);
  if (key.endsWith('_count') || key === 'application_count' || key === 'message_count' || key === 'birth_year') {
    return formatNumber(value);
  }
  if (key === 'restriction_type') return restrictionTypeLabel(value);
  if (key === 'status') return statusLabel(value);
  if (key === 'matching_mode') return matchingModeLabel(value);
  if (key === 'payment_flow') return paymentFlowLabel(value);
  if (key === 'general_payment_status') return generalPaymentStatusLabel(value);
  if (typeof value === 'boolean') return value ? '예' : '아니오';
  if (typeof value === 'string' && /^https?:\/\//.test(value)) {
    return (
      <a href={value} target="_blank" rel="noreferrer">
        링크 열기
      </a>
    );
  }
  if (Array.isArray(value)) return value.map((item) => toText(item)).join(', ');
  return toText(value);
}

function statusLabel(value: unknown): string {
  const text = String(value ?? '');
  const labels: Record<string, string> = {
    open: '접수 중',
    pending: '대기 중',
    reviewing: '검토 중',
    resolved: '처리 완료',
    dismissed: '기각',
    rejected: '거절',
    matched: '매칭됨',
    completed: '완료',
    cancelled: '취소됨',
    failed: '실패',
    selected: '선택됨',
    withdrawn: '지원 철회',
    active: '적용 중',
    scheduled: '예약됨',
    expired: '만료됨',
    revoked: '해제됨',
  };
  return labels[text] ?? restrictionStatusLabel(text);
}

function matchingModeLabel(value: unknown): string {
  if (value === 'quick') return '빠른 매칭';
  if (value === 'general') return '일반 매칭';
  return toText(value);
}

function paymentFlowLabel(value: unknown): string {
  if (value === 'prepaid') return '선결제';
  if (value === 'post_negotiation') return '협의 후 결제';
  return toText(value);
}

function generalPaymentStatusLabel(value: unknown): string {
  if (value === 'pending') return '결제 대기';
  if (value === 'paid') return '결제 완료';
  if (value === 'not_required') return '결제 불필요';
  return toText(value);
}
