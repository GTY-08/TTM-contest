String restrictionErrorMessage(Object? error) {
  final text = error.toString().toLowerCase();
  if (text.contains('moderation_blocked')) {
    return '사용할 수 없는 표현이 포함되어 있어 처리하지 않았어요.';
  }
  if (text.contains('moderation_unavailable')) {
    return '유해 표현 검사에 실패했어요. 잠시 후 다시 시도해 주세요.';
  }
  if (text.contains('request_restricted')) {
    return '현재 ○○ 요청 기능이 제한되어 있습니다.';
  }
  if (text.contains('worker_restricted')) {
    return '현재 작업 수락 기능이 제한되어 있습니다.';
  }
  if (text.contains('chat_restricted')) {
    return '현재 채팅 기능이 제한되어 있습니다.';
  }
  if (text.contains('suspended')) {
    return '현재 계정 이용이 일시적으로 제한되어 있습니다.';
  }
  return '';
}
