export const restrictionTypes = [
  {
    value: 'warning',
    label: '경고',
    description: '서비스 이용은 가능하지만 운영 경고를 명확히 기록합니다.',
  },
  {
    value: 'request_block',
    label: '요청 제한',
    description: '심부름 요청 생성과 게시물 작성을 막습니다.',
  },
  {
    value: 'worker_block',
    label: '작업 제한',
    description: '작업 수락과 지원 등 작업 참여를 막습니다.',
  },
  {
    value: 'matching_block',
    label: '매칭 활동 제한',
    description: '신규 요청과 신규 작업 참여를 막고 진행 중 채팅은 유지합니다.',
  },
  {
    value: 'suspended',
    label: '이용 정지',
    description: '주요 기능을 모두 막고 에스크로 진행 건을 상대방 정산 대상으로 전환합니다.',
  },
] as const;

export const restrictionStatusOptions = [
  { value: 'active', label: '적용 중' },
  { value: 'scheduled', label: '예약됨' },
  { value: 'expired', label: '만료됨' },
  { value: 'revoked', label: '해제됨' },
  { value: 'all', label: '전체' },
] as const;

export function restrictionTypeLabel(value: unknown): string {
  const text = String(value ?? '');
  return restrictionTypes.find((item) => item.value === text)?.label ?? (text || '-');
}

export function restrictionStatusLabel(value: unknown): string {
  const text = String(value ?? '');
  return restrictionStatusOptions.find((item) => item.value === text)?.label ?? (text || '-');
}

export function isActiveRestriction(item: Record<string, unknown>): boolean {
  return effectiveRestrictionStatus(item) === 'active';
}

export function effectiveRestrictionStatus(item: Record<string, unknown>): string {
  if (item.is_active !== true) return 'revoked';

  const startsAt = item.starts_at ? new Date(String(item.starts_at)) : null;
  const endsAt = item.ends_at ? new Date(String(item.ends_at)) : null;
  const now = Date.now();

  if (startsAt && !Number.isNaN(startsAt.getTime()) && startsAt.getTime() > now) {
    return 'scheduled';
  }
  if (endsAt && !Number.isNaN(endsAt.getTime()) && endsAt.getTime() <= now) {
    return 'expired';
  }
  return 'active';
}
