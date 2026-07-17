import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/active_errand_widget_bridge.dart';
import '../../features/match/providers/match_providers.dart';
import 'auth_providers.dart';

/// Android 알림창 "진행 중 심부름" 포그라운드 서비스 노티피케이션을 자동 동기화한다.
///
/// `TtmApp.build()` 안에 `ref.watch(activeErrandWidgetSyncProvider)` 를 추가하면
/// 매칭이 시작·진행·종료될 때마다 노티피케이션을 자동으로 갱신하거나 제거한다.
/// status == "matched" 요청만 감지하며, 완료(completed) 시 노티피케이션은 사라진다.
final activeErrandWidgetSyncProvider = Provider<void>((ref) {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  final userId = ref.watch(authUserIdProvider);
  if (userId == null) {
    unawaited(clearActiveErrand());
    return;
  }

  final matchRepo = ref.watch(matchingRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);

  final sub = matchRepo.watchMyActiveMatchedRequests(userId).listen((
    requests,
  ) async {
    if (requests.isEmpty) {
      await clearActiveErrand();
      return;
    }

    // 가장 최근에 매칭된 요청 하나만 위젯에 표시
    final request = requests.first;

    String? workerNickname;
    double? workerRating;
    try {
      final counterpart = await userRepo.fetchMatchCounterpartProfile(
        request.id,
      );
      workerNickname = counterpart?.nickname;
      workerRating = counterpart?.rating;
    } catch (_) {}

    await updateActiveErrand(
      request: request,
      currentUserId: userId,
      workerDisplayName: workerNickname,
      workerRating: workerRating,
    );
  });

  ref.onDispose(sub.cancel);
});
