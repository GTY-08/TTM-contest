import 'package:flutter/foundation.dart';

import 'match_request.dart';

/// `public.notifications` 한 행. 작업자 화면이 알림 카드를 렌더하는 데 쓴다.
///
/// 알림 자체는 거리·ETA·단계만 있고, 요청 본문(설명·보상·태그) 은 [request] 에 들어 있다.
/// Supabase RPC 의 최소 요청 본문 결과에서 함께 채운다.
@immutable
class WorkerNotification {
  const WorkerNotification({
    required this.id,
    required this.workerId,
    required this.requestId,
    required this.stage,
    required this.distanceKm,
    required this.etaMinutes,
    required this.status,
    required this.createdAt,
    required this.request,
    this.thumbnailUrl,
    this.commentCount = 0,
    this.applicationCount = 0,
    this.myApplicationId,
    this.myApplicationStatus,
  });

  final String id;
  final String workerId;
  final String requestId;
  final int stage;
  final double? distanceKm;
  final int? etaMinutes;
  final String status;
  final DateTime createdAt;
  final MatchRequest? request;
  final String? thumbnailUrl;
  final int commentCount;
  final int applicationCount;
  final String? myApplicationId;
  final String? myApplicationStatus;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isExpired => status == 'expired';
  bool get hasMyGeneralApplication =>
      myApplicationId != null &&
      myApplicationId!.isNotEmpty &&
      (myApplicationStatus == 'pending' || myApplicationStatus == 'selected');

  /// [browse_open_requests] RPC 결과 한 행 → 카드 렌더용 알림 형태.
  factory WorkerNotification.fromBrowseMap(
    Map<String, dynamic> map, {
    required String workerId,
  }) {
    final reqRaw = map['request'];
    MatchRequest? req;
    if (reqRaw is Map) {
      req = MatchRequest.fromMap(Map<String, dynamic>.from(reqRaw));
    }
    final requestId = map['request_id'] as String;
    return WorkerNotification(
      id: 'browse-$requestId',
      workerId: workerId,
      requestId: requestId,
      stage: (map['stage'] as num?)?.toInt() ?? 0,
      distanceKm: _asDouble(map['distance_km']),
      etaMinutes: (map['eta_minutes'] as num?)?.toInt(),
      status: 'pending',
      createdAt: req?.createdAt ?? DateTime.now(),
      request: req,
      thumbnailUrl: map['thumbnail_url']?.toString(),
      commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
      applicationCount: (map['application_count'] as num?)?.toInt() ?? 0,
      myApplicationId: map['my_application_id']?.toString(),
      myApplicationStatus: map['my_application_status']?.toString(),
    );
  }

  factory WorkerNotification.fromMap(Map<String, dynamic> map) {
    final reqRaw = map['requests'] ?? map['request'];
    MatchRequest? req;
    if (reqRaw is Map) {
      req = MatchRequest.fromMap(Map<String, dynamic>.from(reqRaw));
    }
    return WorkerNotification(
      id: map['id'] as String,
      workerId: map['worker_id'] as String,
      requestId: map['request_id'] as String,
      stage: (map['stage'] as num?)?.toInt() ?? 0,
      distanceKm: _asDouble(map['distance_km']),
      etaMinutes: (map['eta_minutes'] as num?)?.toInt(),
      status: (map['status'] as String?) ?? 'pending',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      request: req,
      thumbnailUrl: map['thumbnail_url']?.toString(),
      commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
      applicationCount: (map['application_count'] as num?)?.toInt() ?? 0,
    );
  }

  static double? _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}
