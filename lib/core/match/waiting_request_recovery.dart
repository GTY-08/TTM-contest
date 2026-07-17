import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../features/match/providers/match_providers.dart';

/// 앱 강제 종료 등으로 매칭 대기 화면을 벗어난 open 요청을 취소한다.
final waitingRequestRecoveryProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(prefsProvider);
  final requestId = prefs.waitingMatchRequestId;
  if (requestId == null) return;

  final uid = ref.read(authUserIdProvider);
  if (uid == null) {
    await prefs.clearWaitingMatchRequestId();
    return;
  }

  try {
    final repo = ref.read(matchingRepositoryProvider);
    final req = await repo.fetchRequest(requestId);
    if (req != null &&
        req.isOpen &&
        req.requesterId == uid &&
        req.isQuickMatching) {
      await repo.cancelRequest(requestId);
    }
  } catch (_) {}

  await prefs.clearWaitingMatchRequestId();
});
