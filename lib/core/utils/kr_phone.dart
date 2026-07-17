/// 한국 휴대폰 번호를 E.164 로 정규화한다. 실패 시 null.
///
/// 허용 예: `01012345678`, `010-1234-5678`, `+821012345678`
String? krMobileToE164(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('82') && digits.length >= 12) {
    return '+$digits';
  }
  if (digits.length == 11 && digits.startsWith('010')) {
    return '+82${digits.substring(1)}';
  }
  return null;
}

/// 표시용 (예: 010-1234-5678). E.164 가 아니면 원문 trim 만 반환.
String formatKrMobileDisplay(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('010')) {
    return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  }
  return raw.trim();
}
