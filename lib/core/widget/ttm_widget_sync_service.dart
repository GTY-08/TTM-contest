import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/match/models/general_request_applicant.dart';
import '../../features/match/models/match_request.dart';
import '../../features/match/models/worker_notification.dart';

class TtmWidgetSyncService {
  const TtmWidgetSyncService._();

  static const MethodChannel _channel = MethodChannel(
    'com.ttm.ttm_app/widgets',
  );

  static Future<void> syncNearbyErrands(
    List<WorkerNotification> notifications,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = notifications
        .where((n) => n.request != null)
        .map((n) {
          final request = n.request!;
          return <String, Object?>{
            'taskType': request.taskType,
            'title': request.displayTitle,
            'distance': _distanceLabel(n.distanceKm),
            'rewardWon': request.negotiatedReward ?? request.reward,
            'route': '/request/${request.id}/waiting',
          };
        })
        .take(10)
        .toList(growable: false);

    await prefs.setString('nearby_errands', jsonEncode(rows));
    await prefs.setInt('nearby_count', notifications.length);
    await _updateWidgets('nearby');
  }

  static Future<void> syncWorkItems({
    required List<MatchRequest> activeRequests,
    required List<GeneralRequestApplicationSummary> applications,
  }) async {
    final rows = <Map<String, Object?>>[
      for (final request in activeRequests)
        <String, Object?>{
          'kind': 'active',
          'status': '진행중',
          'taskType': request.taskType,
          'title': request.displayTitle,
          'subtitle': request.isAwaitingRequesterConfirm
              ? '완료 확인 대기'
              : '진행 화면으로 이동',
          'rewardWon': request.negotiatedReward ?? request.reward,
          'route': '/request/${request.id}/active',
          'sortAt': request.matchedAt?.toIso8601String(),
        },
      for (final application in applications.where((a) => a.isPending))
        <String, Object?>{
          'kind': 'application',
          'status': '지원중',
          'taskType': application.request.taskType,
          'title': application.request.displayTitle,
          'subtitle': '요청자 선택 대기',
          'rewardWon':
              application.request.negotiatedReward ??
              application.request.reward,
          'route':
              '/request/${application.requestId}/applications/${application.applicationId}/chat',
          'sortAt': application.createdAt.toIso8601String(),
        },
    ];

    rows.sort((a, b) {
      final at = DateTime.tryParse(a['sortAt']?.toString() ?? '');
      final bt = DateTime.tryParse(b['sortAt']?.toString() ?? '');
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('work_items', jsonEncode(rows.take(20).toList()));
    await prefs.setInt('work_item_count', rows.length);
    await _updateWidgets('work');
  }

  /// 활동 ON/OFF 위젯 상태 동기화.
  ///
  /// worker_presence 행(realtime)을 그대로 받아 위젯이 읽는 프리퍼런스로 옮긴다.
  /// 위젯 쪽(Kotlin)에서도 같은 키를 직접 갱신하므로 키·형식을 바꾸면 안 된다.
  static Future<void> syncActivityState(Map<String, dynamic>? presence) async {
    final prefs = await SharedPreferences.getInstance();
    final status = presence?['status']?.toString();
    final isOnline = status == 'online' || status == 'busy';
    final untilRaw = presence?['online_until']?.toString();
    final until = untilRaw == null ? null : DateTime.tryParse(untilRaw);

    if (!isOnline || until == null || !until.isAfter(DateTime.now())) {
      await prefs.setString('widget_activity_status', 'offline');
      await prefs.remove('widget_activity_until');
    } else {
      final untilMs = until.millisecondsSinceEpoch.toString();
      final prevUntil = prefs.getString('widget_activity_until');
      if (prevUntil != untilMs) {
        // 종료 시각이 바뀐 경우에만 총 시간 재산정 (진행 링·바 기준값)
        final totalMin = until.difference(DateTime.now()).inMinutes + 1;
        await prefs.setString('widget_activity_total_min', '$totalMin');
      }
      await prefs.setString('widget_activity_status', 'online');
      await prefs.setString('widget_activity_until', untilMs);
      final radius = presence?['max_distance_km'];
      if (radius != null) {
        await prefs.setString('widget_activity_radius_km', radius.toString());
      }
    }
    await _updateWidgets('activity');
  }

  /// [scope] 는 이번에 갱신한 데이터 영역('nearby' | 'work' | 'activity').
  /// iOS 브리지가 해당 영역의 키만 App Group 으로 복사한다 — 위젯이 직접 쓴
  /// 다른 영역 상태(예: 활동 ON)를 오래된 값으로 덮어쓰지 않기 위함.
  /// Android 핸들러는 인자를 무시하고 전체 위젯을 새로 그린다.
  static Future<void> _updateWidgets(String scope) async {
    try {
      await _channel.invokeMethod<void>('updateWidgets', {'scope': scope});
    } on MissingPluginException {
      // 위젯 채널이 없는 플랫폼에서는 저장만 하고 끝낸다.
    } on PlatformException {
      // 위젯 갱신 실패가 앱 화면 동작을 막으면 안 된다.
    }
  }

  static String _distanceLabel(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()}m';
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)}km';
  }
}
