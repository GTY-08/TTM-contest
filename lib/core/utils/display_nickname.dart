/// UI에 표시할 닉네임 (빈 값·공백 → fallback).
String ttmDisplayNickname(String? nickname, {String fallback = '상대방'}) {
  final trimmed = nickname?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return fallback;
}
