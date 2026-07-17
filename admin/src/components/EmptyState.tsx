export function EmptyState({ message = '표시할 데이터가 없습니다.' }) {
  return <div className="empty-state">{message}</div>;
}
