/// 페널티 종료 시각까지 남은 시간을 사람이 읽기 쉬운 문자열로.
String formatPenaltyRemaining(DateTime until) {
  final diff = until.difference(DateTime.now());
  if (diff.isNegative || diff.inSeconds <= 0) return '곧';
  if (diff.inDays >= 1) return '${diff.inDays}일';
  if (diff.inHours >= 1) return '${diff.inHours}시간';
  final mins = diff.inMinutes.clamp(1, 59);
  return '$mins분';
}
