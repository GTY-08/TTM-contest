String normalizeModerationText(String value) {
  return value.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9\u3131-\u318e\uac00-\ud7a3]+'),
    '',
  );
}

String? localTextModerationReason(String value) {
  final normalized = normalizeModerationText(value);
  if (normalized.isEmpty) return null;

  final sexual = RegExp(
    r'(강간|성폭행|자지|보지|섹스|딸딸|애무|sex|rape)',
    caseSensitive: false,
  );
  if (sexual.hasMatch(normalized)) {
    return 'sexual_or_abusive_language';
  }

  // Avoid treating the common non-abusive word as the "시발" variant.
  final abuseCandidate = normalized.replaceAll('시발점', '');
  final strongAbuse = RegExp(
    r'(씨+발+|시+발+|씨+팔+|시+팔+|씨8|시8|ㅅ8|ㅆ+발+|ㅆ+팔+|'
    r'ㅅㅂ|ㅆㅂ|ㅂㅅ|ㅄ|씹+|병+신|개+새+끼|개+색+기|새+끼|'
    r'좆|존+나|지+랄|닥+쳐|꺼+져|쌍+년|'
    r'ssibal|shibal|fuck|bitch|cunt)',
    caseSensitive: false,
  );
  if (strongAbuse.hasMatch(abuseCandidate)) {
    return 'explicit_abusive_language';
  }

  return null;
}
