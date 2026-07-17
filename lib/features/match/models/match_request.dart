import 'package:flutter/foundation.dart';

import '../../../core/constants/matching_constants.dart';
import '../../../core/utils/geo_point_parse.dart';
import 'request_task_type.dart';

/// `public.requests` 한 행을 Flutter 도메인 객체로 표현한 것.
///
/// PostGIS `geo`는 [requestLatitude]/[requestLongitude] 로 파싱된다.
@immutable
class MatchRequest {
  const MatchRequest({
    required this.id,
    required this.requesterId,
    required this.title,
    required this.description,
    required this.tags,
    required this.taskType,
    required this.taskOptions,
    required this.taskProofPolicyVersion,
    required this.reward,
    required this.rewardMin,
    required this.rewardMax,
    required this.negotiatedReward,
    required this.negotiatedAt,
    required this.paymentFlow,
    required this.generalPaymentStatus,
    required this.paymentRequiredAt,
    required this.paymentConfirmedAt,
    required this.paymentEnforcementRequired,
    required this.deadline,
    required this.estimatedTaskMinutes,
    required this.maxSearchRadiusM,
    required this.status,
    required this.currentStage,
    required this.nextAdvanceAt,
    required this.stageIntervalSeconds,
    required this.matchingMode,
    required this.createdAt,
    required this.matchedAt,
    required this.completedAt,
    required this.failedAt,
    required this.completionRequestedAt,
    required this.completionRequestedBy,
    required this.completionRejectedAt,
    required this.completionRejectCount,
    required this.nextCompletionRequestAt,
    required this.completionAutoCompleteAt,
    required this.workerId,
    required this.notes,
    this.requestLatitude,
    this.requestLongitude,
    this.requesterShareLocation = false,
    this.requesterLiveLatitude,
    this.requesterLiveLongitude,
    this.workerLiveLatitude,
    this.workerLiveLongitude,
    this.thumbnailUrl,
    this.commentCount = 0,
    this.applicationCount = 0,
  });

  final String id;
  final String requesterId;
  final String? title;
  final String description;
  final List<String> tags;
  final String taskType;
  final Map<String, dynamic> taskOptions;
  final int taskProofPolicyVersion;
  final num reward;
  final num? rewardMin;
  final num? rewardMax;
  final num? negotiatedReward;
  final DateTime? negotiatedAt;
  final String paymentFlow;
  final String generalPaymentStatus;
  final DateTime? paymentRequiredAt;
  final DateTime? paymentConfirmedAt;
  final bool paymentEnforcementRequired;
  final DateTime deadline;
  final int estimatedTaskMinutes;
  final int maxSearchRadiusM;
  final String status;
  final int currentStage;
  final DateTime nextAdvanceAt;
  final int stageIntervalSeconds;
  final String matchingMode;
  final DateTime createdAt;
  final DateTime? matchedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? completionRequestedAt;
  final String? completionRequestedBy;
  final DateTime? completionRejectedAt;
  final int completionRejectCount;
  final DateTime? nextCompletionRequestAt;
  final DateTime? completionAutoCompleteAt;
  final String? workerId;
  final String? notes;
  final double? requestLatitude;
  final double? requestLongitude;
  final bool requesterShareLocation;
  final double? requesterLiveLatitude;
  final double? requesterLiveLongitude;
  final double? workerLiveLatitude;
  final double? workerLiveLongitude;
  final String? thumbnailUrl;
  final int commentCount;
  final int applicationCount;

  bool get isOpen => status == 'open';
  bool get isMatched => status == 'matched';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isFailed => status == 'failed';
  bool get isQuickMatching => matchingMode == 'quick';
  bool get isGeneralMatching => matchingMode == 'general';
  RequestTaskPolicy get taskPolicy => RequestTaskPolicy(
    type: RequestTaskType.fromId(taskType),
    options: taskOptions,
  );
  bool get isPostNegotiationPayment => paymentFlow == 'post_negotiation';
  bool get isPaymentPending =>
      paymentEnforcementRequired &&
      isPostNegotiationPayment &&
      generalPaymentStatus == 'pending';

  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return description;
  }

  String rewardLabel({String suffix = '원'}) {
    String fmt(num value) => value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    if (negotiatedReward != null) return '${fmt(negotiatedReward!)}$suffix';
    if (isGeneralMatching && rewardMin != null && rewardMax != null) {
      if (rewardMin == rewardMax) return '${fmt(rewardMin!)}$suffix';
      return '${fmt(rewardMin!)}~${fmt(rewardMax!)}$suffix';
    }
    return '${fmt(reward)}$suffix';
  }

  /// 작업자가 완료를 요청했고 요청자 확인을 기다리는 중.
  bool get isAwaitingRequesterConfirm =>
      isMatched && completionRequestedAt != null;

  bool get canRequestCompletionNow =>
      isMatched &&
      completionRequestedAt == null &&
      (nextCompletionRequestAt == null ||
          !nextCompletionRequestAt!.isAfter(DateTime.now()));

  /// 현재 단계의 반경(m). 0단계(생성 직후 1ms)에서는 0 으로 본다.
  double get currentRadiusM =>
      maxSearchRadiusM * currentStage.clamp(0, 10) / 10.0;

  factory MatchRequest.fromMap(Map<String, dynamic> map) {
    final geo = TtmGeoPoint.tryParse(map['geo']);
    final requesterLive = TtmGeoPoint.tryParse(map['requester_live_geo']);
    final workerLive = TtmGeoPoint.tryParse(map['worker_live_geo']);
    return MatchRequest(
      id: map['id'] as String,
      requesterId: map['requester_id'] as String,
      title: map['title'] as String?,
      description: (map['description'] as String?) ?? '',
      tags: _asStringList(map['tags']),
      taskType:
          (map['task_type'] as String?) ??
          RequestTaskType.fromLegacyTags(_asStringList(map['tags'])).id,
      taskOptions: _asStringMap(map['task_options']),
      taskProofPolicyVersion: _asInt(map['task_proof_policy_version']) ?? 0,
      reward: _asNum(map['reward']) ?? 0,
      rewardMin: _asNum(map['reward_min']),
      rewardMax: _asNum(map['reward_max']),
      negotiatedReward: _asNum(map['negotiated_reward']),
      negotiatedAt: _parseTs(map['negotiated_at']),
      paymentFlow: (map['payment_flow'] as String?) ?? 'prepaid',
      generalPaymentStatus:
          (map['general_payment_status'] as String?) ?? 'not_required',
      paymentRequiredAt: _parseTs(map['payment_required_at']),
      paymentConfirmedAt: _parseTs(map['payment_confirmed_at']),
      paymentEnforcementRequired: map['payment_enforcement_required'] == true,
      deadline: _parseTs(map['deadline']) ?? DateTime.now(),
      estimatedTaskMinutes: _asInt(map['estimated_task_minutes']) ?? 0,
      maxSearchRadiusM: _asInt(map['max_search_radius_m']) ?? 0,
      status: (map['status'] as String?) ?? 'open',
      currentStage: _asInt(map['current_stage']) ?? 0,
      nextAdvanceAt: _parseTs(map['next_advance_at']) ?? DateTime.now(),
      stageIntervalSeconds:
          _asInt(map['stage_interval_seconds']) ??
          TtmMatchingConstants.defaultStageIntervalSeconds,
      matchingMode: (map['matching_mode'] as String?) ?? 'quick',
      createdAt: _parseTs(map['created_at']) ?? DateTime.now(),
      matchedAt: _parseTs(map['matched_at']),
      completedAt: _parseTs(map['completed_at']),
      failedAt: _parseTs(map['failed_at']),
      completionRequestedAt: _parseTs(map['completion_requested_at']),
      completionRequestedBy: map['completion_requested_by'] as String?,
      completionRejectedAt: _parseTs(map['completion_rejected_at']),
      completionRejectCount: _asInt(map['completion_reject_count']) ?? 0,
      nextCompletionRequestAt: _parseTs(map['next_completion_request_at']),
      completionAutoCompleteAt: _parseTs(map['completion_auto_complete_at']),
      workerId: map['worker_id'] as String?,
      notes: map['notes'] as String?,
      requestLatitude: geo?.latitude,
      requestLongitude: geo?.longitude,
      requesterShareLocation: map['requester_share_location'] == true,
      requesterLiveLatitude: requesterLive?.latitude,
      requesterLiveLongitude: requesterLive?.longitude,
      workerLiveLatitude: workerLive?.latitude,
      workerLiveLongitude: workerLive?.longitude,
      thumbnailUrl: map['thumbnail_url']?.toString(),
      commentCount: _asInt(map['comment_count']) ?? 0,
      applicationCount: _asInt(map['application_count']) ?? 0,
    );
  }

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static num? _asNum(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw);
    return null;
  }

  static List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  static Map<String, dynamic> _asStringMap(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }
}
