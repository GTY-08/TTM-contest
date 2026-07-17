import 'match_request.dart';

class RequestTaskProof {
  const RequestTaskProof({
    required this.id,
    required this.requestId,
    required this.workerId,
    required this.proofType,
    required this.imageUrl,
    required this.createdAt,
    required this.reviewStatus,
    required this.reviewReason,
    required this.reviewedAt,
  });

  final String id;
  final String requestId;
  final String workerId;
  final String proofType;
  final String imageUrl;
  final DateTime createdAt;
  final String reviewStatus;
  final String? reviewReason;
  final DateTime? reviewedAt;

  bool get isRejected => reviewStatus == 'rejected';
  bool get isAccepted => reviewStatus == 'accepted';
  bool get isPending => reviewStatus == 'pending';

  factory RequestTaskProof.fromMap(Map<String, dynamic> map) {
    return RequestTaskProof(
      id: map['id'] as String,
      requestId: map['request_id'] as String,
      workerId: map['worker_id'] as String,
      proofType: map['proof_type'] as String,
      imageUrl: map['image_url'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      reviewStatus: map['review_status']?.toString() ?? 'pending',
      reviewReason: map['review_reason']?.toString(),
      reviewedAt: map['reviewed_at'] == null
          ? null
          : DateTime.tryParse(map['reviewed_at'].toString()),
    );
  }

  RequestTaskProof copyWithImageUrl(String value) {
    return RequestTaskProof(
      id: id,
      requestId: requestId,
      workerId: workerId,
      proofType: proofType,
      imageUrl: value,
      createdAt: createdAt,
      reviewStatus: reviewStatus,
      reviewReason: reviewReason,
      reviewedAt: reviewedAt,
    );
  }
}

class TaskProofRequirement {
  const TaskProofRequirement({
    required this.proofType,
    required this.label,
    required this.description,
    this.requiredCount = 1,
    this.intervalMinutes,
  });

  final String proofType;
  final String label;
  final String description;
  final int requiredCount;
  final int? intervalMinutes;
}

abstract final class TaskProofPlan {
  static List<TaskProofRequirement> forRequest(MatchRequest request) {
    if (request.taskProofPolicyVersion <= 0) return const [];
    final options = request.taskOptions;
    switch (request.taskPolicy.type.id) {
      case 'delivery':
        if (options['service_kind'] == 'transport') {
          return const [
            TaskProofRequirement(
              proofType: 'load_before_photo',
              label: '운반 전 짐',
              description: '옮기기 전 짐의 상태와 수량이 보이게 촬영해 주세요.',
            ),
            TaskProofRequirement(
              proofType: 'arrival_photo',
              label: '도착 완료',
              description: '목적지에 내려놓은 짐 전체가 보이게 촬영해 주세요.',
            ),
          ];
        }
        return const [
          TaskProofRequirement(
            proofType: 'pickup_photo',
            label: '물품 수령',
            description: '수령한 물품의 상태가 보이게 촬영해 주세요.',
          ),
          TaskProofRequirement(
            proofType: 'delivery_photo',
            label: '전달 완료',
            description: '요청 장소에 전달한 상태를 촬영해 주세요.',
          ),
        ];
      case 'purchase':
        return const [
          TaskProofRequirement(
            proofType: 'receipt_photo',
            label: '영수증',
            description: '상호, 품목, 금액이 선명하게 보이도록 촬영해 주세요.',
          ),
          TaskProofRequirement(
            proofType: 'purchased_item_photo',
            label: '구매 물품',
            description: '구매한 물품 전체가 보이게 촬영해 주세요.',
          ),
        ];
      case 'cleaning':
        return const [
          TaskProofRequirement(
            proofType: 'cleaning_before_photo',
            label: '청소 전',
            description: '작업 범위 전체가 보이도록 촬영해 주세요.',
          ),
          TaskProofRequirement(
            proofType: 'cleaning_after_photo',
            label: '청소 후',
            description: '청소 전 사진과 같은 방향에서 촬영해 주세요.',
          ),
        ];
      case 'waiting':
        final duration = _intOption(options, 'waiting_duration_minutes', 60);
        final interval = _intOption(options, 'proof_interval_minutes', 30);
        return [
          TaskProofRequirement(
            proofType: 'waiting_photo',
            label: '대기 현장',
            description: '현재 대기 중인 장소와 상황이 보이게 촬영해 주세요.',
            requiredCount: duration ~/ interval + 1,
            intervalMinutes: interval,
          ),
        ];
      case 'pet':
        final duration = _intOption(options, 'care_duration_minutes', 30);
        final interval = _intOption(options, 'proof_interval_minutes', 30);
        final checkins = ((duration + interval - 1) ~/ interval - 1).clamp(
          0,
          24,
        );
        return [
          const TaskProofRequirement(
            proofType: 'care_start_photo',
            label: '돌봄 시작',
            description: '돌봄 대상과 시작 환경이 보이게 촬영해 주세요.',
          ),
          if (checkins > 0)
            TaskProofRequirement(
              proofType: 'care_checkin_photo',
              label: '돌봄 지속 인증',
              description: '대기형처럼 선택한 간격마다 돌봄 상태를 인증해 주세요.',
              requiredCount: checkins,
              intervalMinutes: interval,
            ),
          const TaskProofRequirement(
            proofType: 'care_end_photo',
            label: '돌봄 종료',
            description: '돌봄이 끝난 상태를 촬영해 주세요.',
          ),
        ];
      default:
        return const [];
    }
  }

  static int _intOption(
    Map<String, dynamic> options,
    String key,
    int fallback,
  ) {
    final raw = options[key];
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? fallback;
  }
}
