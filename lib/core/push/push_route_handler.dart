import 'package:flutter/foundation.dart';

/// FCM data payload → 앱 내비게이션 의도.
@immutable
class PushNavigationIntent {
  const PushNavigationIntent({
    required this.pushType,
    this.route,
    this.homeTabIndex,
    this.requestId,
  });

  final String pushType;
  final String? route;
  final int? homeTabIndex;
  final String? requestId;

  factory PushNavigationIntent.fromData(Map<String, dynamic> data) {
    final pushType = (data['push_type'] ?? data['type'] ?? '').toString();
    final route = data['route']?.toString();
    final requestId = data['request_id']?.toString();

    int? tab;
    if (route != null && route.contains('tab=notifications')) {
      tab = 2;
    }
    if (pushType == 'worker_match_offer' ||
        pushType == 'exercise_match_offer' ||
        pushType == 'raid_recruitment_offer') {
      tab = 2;
    }

    return PushNavigationIntent(
      pushType: pushType,
      route: route,
      homeTabIndex: tab,
      requestId: requestId,
    );
  }

  /// go_router 경로. route 필드 우선, 없으면 type 기반 fallback.
  String? resolveGoPath() {
    final raw = route;
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('/')) return _stripQuery(raw);
      if (raw.startsWith('home?tab=notifications')) return '/home';
    }
    final id = requestId;
    if (id == null || id.isEmpty) {
      if (pushType == 'worker_match_offer') return '/home';
      return null;
    }
    switch (pushType) {
      case 'requester_matched':
      case 'completion_requested':
      case 'chat_message':
        return '/request/$id/active';
      case 'requester_match_failed':
        return '/request/$id/waiting';
      default:
        return null;
    }
  }

  static String _stripQuery(String path) {
    final q = path.indexOf('?');
    return q < 0 ? path : path.substring(0, q);
  }
}
