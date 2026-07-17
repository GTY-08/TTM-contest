const toneByStatus: Record<string, string> = {
  open: 'info',
  pending: 'warning',
  reviewing: 'info',
  matched: 'success',
  selected: 'success',
  completed: 'success',
  resolved: 'success',
  paid: 'success',
  active: 'danger',
  scheduled: 'warning',
  cancelled: 'danger',
  failed: 'danger',
  rejected: 'danger',
  dismissed: 'danger',
  withdrawn: 'neutral',
  expired: 'neutral',
  revoked: 'success',
  '접수 중': 'info',
  '대기 중': 'warning',
  '검토 중': 'info',
  '매칭됨': 'success',
  '선택됨': 'success',
  완료: 'success',
  '처리 완료': 'success',
  '적용 중': 'danger',
  예약됨: 'warning',
  취소됨: 'danger',
  실패: 'danger',
  거절: 'danger',
  기각: 'danger',
  '지원 철회': 'neutral',
  만료됨: 'neutral',
  해제됨: 'success',
};

const statusLabels: Record<string, string> = {
  open: '접수 중',
  pending: '대기 중',
  reviewing: '검토 중',
  matched: '매칭됨',
  selected: '선택됨',
  completed: '완료',
  resolved: '처리 완료',
  paid: '결제 완료',
  cancelled: '취소됨',
  failed: '실패',
  rejected: '거절',
  dismissed: '기각',
  withdrawn: '지원 철회',
  active: '적용 중',
  scheduled: '예약됨',
  expired: '만료됨',
  revoked: '해제됨',
};

export function StatusBadge({ status }: { status: unknown }) {
  const raw = String(status ?? '-');
  const text = statusLabels[raw] ?? raw;
  const tone = toneByStatus[raw] ?? toneByStatus[text] ?? 'neutral';
  return <span className={`status ${tone}`}>{text}</span>;
}
