import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../features/match/models/match_request.dart';

const _channel = MethodChannel('com.ttm.ttm_app/active_errand');

/// 진행 중 심부름 상태 알림을 시작·갱신·종료한다.
///
/// Android에서는 [ActiveErrandService] 포그라운드 알림,
/// iOS에서는 라이브 액티비티(잠금화면·다이내믹 아일랜드)를 실행한다.
/// 다른 플랫폼에서는 아무 동작도 하지 않는다.

Future<void> updateActiveErrand({
  required MatchRequest request,
  required String currentUserId,
  String? workerDisplayName,
  double? workerRating,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    final stage = _widgetStage(request);
    final role = currentUserId == request.requesterId ? 'requester' : 'worker';
    final reward = (request.negotiatedReward ?? request.reward).toInt();

    await _channel.invokeMethod('update', {
      'stage': stage,
      'workerName': workerDisplayName ?? '작업자',
      'workerRating': workerRating ?? 0.0,
      'title': request.displayTitle,
      'rewardWon': reward,
      'role': role,
      'requestId': request.id,
    });
  } catch (_) {}
}

Future<void> clearActiveErrand() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    await _channel.invokeMethod('stop');
  } catch (_) {}
}

int _widgetStage(MatchRequest req) {
  if (req.isCompleted) return 4;
  if (req.isMatched && req.completionRequestedAt != null) return 3;
  if (req.isMatched) {
    final matchedAt = req.matchedAt;
    if (matchedAt != null &&
        DateTime.now().difference(matchedAt).inMinutes < 5) {
      return 1; // 수락됨
    }
    return 2; // 수행 중
  }
  return 0; // 찾는 중
}
