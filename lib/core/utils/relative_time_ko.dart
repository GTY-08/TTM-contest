/// 알림·피드용 상대 시각 (한국어).
String formatRelativeTimeKo(DateTime createdAt, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(createdAt);
  if (diff.isNegative || diff.inSeconds < 45) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}
