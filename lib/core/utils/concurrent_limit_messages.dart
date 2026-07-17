import 'package:postgrest/postgrest.dart';

/// 동시 한도 — 요청 등록 + 작업 수락 **합산** (일반 1 / 프리미엄 3).
String concurrentSlotLimitMessage({required bool isPremium}) {
  final limit = isPremium ? 3 : 1;
  return isPremium
      ? '진행·대기 중인 심부름이 이미 $limit건이에요. (요청+작업 합산) 하나 끝낸 뒤 다시 시도해 주세요.'
      : '진행·대기 중인 심부름이 이미 $limit건이에요. 프리미엄은 요청·작업 합쳐 최대 3건까지 가능해요.';
}

String concurrentLimitUserMessage(Object error, {required bool isPremium}) {
  if (_isSlotLimitError(error)) {
    return concurrentSlotLimitMessage(isPremium: isPremium);
  }
  return '';
}

String acceptConcurrentLimitMessage(String? reason, {required bool isPremium}) {
  if (reason != 'concurrent_slot_limit' &&
      reason != 'concurrent_worker_limit' &&
      reason != 'concurrent_requester_limit') {
    return '';
  }
  return concurrentSlotLimitMessage(isPremium: isPremium);
}

bool _isSlotLimitError(Object error) {
  if (error is PostgrestException) {
    final m = error.message;
    return m.contains('concurrent_slot_limit') ||
        m.contains('concurrent_requester_limit') ||
        m.contains('concurrent_worker_limit');
  }
  return false;
}
