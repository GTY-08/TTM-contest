import 'package:flutter/foundation.dart';

import 'match_request.dart';

@immutable
class GeneralRequestApplicant {
  const GeneralRequestApplicant({
    required this.applicationId,
    required this.requestId,
    required this.workerId,
    required this.status,
    required this.createdAt,
    this.initialMessage,
    this.selectedAt,
    this.workerNickname,
    this.workerProfileImageUrl,
    this.workerRating,
    this.workerRatingCount,
    this.workerTrustScore,
    this.proposedReward,
    this.proposedBy,
    this.proposedAt,
    this.requesterAcceptedAt,
    this.workerAcceptedAt,
  });

  final String applicationId;
  final String requestId;
  final String workerId;
  final String status;
  final String? initialMessage;
  final DateTime createdAt;
  final DateTime? selectedAt;
  final String? workerNickname;
  final String? workerProfileImageUrl;
  final num? workerRating;
  final int? workerRatingCount;
  final int? workerTrustScore;
  final num? proposedReward;
  final String? proposedBy;
  final DateTime? proposedAt;
  final DateTime? requesterAcceptedAt;
  final DateTime? workerAcceptedAt;

  bool get agreementReady =>
      proposedReward != null &&
      requesterAcceptedAt != null &&
      workerAcceptedAt != null;

  factory GeneralRequestApplicant.fromMap(Map<String, dynamic> map) {
    return GeneralRequestApplicant(
      applicationId: map['application_id'] as String,
      requestId: map['request_id'] as String,
      workerId: map['worker_id'] as String,
      status: (map['status'] as String?) ?? 'pending',
      initialMessage: map['initial_message'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      selectedAt: DateTime.tryParse(map['selected_at']?.toString() ?? ''),
      workerNickname: map['worker_nickname'] as String?,
      workerProfileImageUrl: map['worker_profile_image_url'] as String?,
      workerRating: _asNum(map['worker_rating']),
      workerRatingCount: _asInt(map['worker_rating_count']),
      workerTrustScore: _asInt(map['worker_trust_score']),
      proposedReward: _asNum(map['proposed_reward']),
      proposedBy: map['proposed_by']?.toString(),
      proposedAt: _parseTs(map['proposed_at']),
      requesterAcceptedAt: _parseTs(map['requester_accepted_at']),
      workerAcceptedAt: _parseTs(map['worker_accepted_at']),
    );
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

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}

@immutable
class GeneralRequestApplicationSummary {
  const GeneralRequestApplicationSummary({
    required this.applicationId,
    required this.requestId,
    required this.status,
    required this.createdAt,
    required this.request,
    this.initialMessage,
    this.proposedReward,
    this.proposedBy,
    this.proposedAt,
    this.requesterAcceptedAt,
    this.workerAcceptedAt,
  });

  final String applicationId;
  final String requestId;
  final String status;
  final DateTime createdAt;
  final MatchRequest request;
  final String? initialMessage;
  final num? proposedReward;
  final String? proposedBy;
  final DateTime? proposedAt;
  final DateTime? requesterAcceptedAt;
  final DateTime? workerAcceptedAt;

  bool get isPending => status == 'pending';
  bool get isSelected => status == 'selected';
  bool get agreementReady =>
      proposedReward != null &&
      requesterAcceptedAt != null &&
      workerAcceptedAt != null;

  factory GeneralRequestApplicationSummary.fromMap(Map<String, dynamic> map) {
    final rawRequest = map['requests'] ?? map['request'];
    return GeneralRequestApplicationSummary(
      applicationId: map['id']?.toString() ?? '',
      requestId: map['request_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      initialMessage: map['initial_message']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      proposedReward: GeneralRequestApplicant._asNum(map['proposed_reward']),
      proposedBy: map['proposed_by']?.toString(),
      proposedAt: GeneralRequestApplicant._parseTs(map['proposed_at']),
      requesterAcceptedAt: GeneralRequestApplicant._parseTs(
        map['requester_accepted_at'],
      ),
      workerAcceptedAt: GeneralRequestApplicant._parseTs(
        map['worker_accepted_at'],
      ),
      request: MatchRequest.fromMap(
        Map<String, dynamic>.from(rawRequest as Map),
      ),
    );
  }
}

@immutable
class GeneralApplicationAgreement {
  const GeneralApplicationAgreement({
    required this.applicationId,
    required this.requestId,
    required this.workerId,
    required this.status,
    this.proposedReward,
    this.proposedBy,
    this.proposedAt,
    this.requesterAcceptedAt,
    this.workerAcceptedAt,
  });

  final String applicationId;
  final String requestId;
  final String workerId;
  final String status;
  final num? proposedReward;
  final String? proposedBy;
  final DateTime? proposedAt;
  final DateTime? requesterAcceptedAt;
  final DateTime? workerAcceptedAt;

  bool get agreementReady =>
      proposedReward != null &&
      requesterAcceptedAt != null &&
      workerAcceptedAt != null;

  bool acceptedBy(String? userId) {
    if (userId == null) return false;
    return proposedBy == userId ||
        requesterAcceptedAt != null && workerAcceptedAt != null;
  }

  factory GeneralApplicationAgreement.fromMap(Map<String, dynamic> map) {
    return GeneralApplicationAgreement(
      applicationId: map['id']?.toString() ?? '',
      requestId: map['request_id']?.toString() ?? '',
      workerId: map['worker_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      proposedReward: GeneralRequestApplicant._asNum(map['proposed_reward']),
      proposedBy: map['proposed_by']?.toString(),
      proposedAt: GeneralRequestApplicant._parseTs(map['proposed_at']),
      requesterAcceptedAt: GeneralRequestApplicant._parseTs(
        map['requester_accepted_at'],
      ),
      workerAcceptedAt: GeneralRequestApplicant._parseTs(
        map['worker_accepted_at'],
      ),
    );
  }
}
