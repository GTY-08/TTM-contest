import 'request_tag.dart';

/// 요청의 생성 폼과 진행 규칙을 결정하는 핵심 심부름 유형.
class RequestTaskType {
  const RequestTaskType._({
    required this.id,
    required this.label,
    required this.description,
    required this.legacyTag,
  });

  final String id;
  final String label;
  final String description;
  final String legacyTag;

  static const delivery = RequestTaskType._(
    id: 'delivery',
    label: '배달 및 운반',
    description: '물건을 전달하거나 짐을 옮기는 작업',
    legacyTag: TtmRequestTags.delivery,
  );
  static const purchase = RequestTaskType._(
    id: 'purchase',
    label: '구매',
    description: '상품을 대신 구매하고 전달하는 작업',
    legacyTag: TtmRequestTags.purchase,
  );
  static const cleaning = RequestTaskType._(
    id: 'cleaning',
    label: '청소',
    description: '정해진 공간을 청소하거나 정리하는 작업',
    legacyTag: TtmRequestTags.cleaning,
  );
  static const waiting = RequestTaskType._(
    id: 'waiting',
    label: '대기',
    description: '한 장소에서 줄서기 등 일정 시간 대기하는 작업',
    legacyTag: TtmRequestTags.waiting,
  );
  static const pet = RequestTaskType._(
    id: 'pet',
    label: '반려 및 돌봄',
    description: '반려동물 산책과 사람·동물 돌봄 작업',
    legacyTag: TtmRequestTags.pet,
  );
  static const other = RequestTaskType._(
    id: 'other',
    label: '기타',
    description: '위 유형에 해당하지 않는 작업',
    legacyTag: TtmRequestTags.etc,
  );

  static const values = [delivery, purchase, cleaning, waiting, pet, other];

  static RequestTaskType fromId(String? id) {
    if (id == 'moving') return delivery;
    if (id == 'document') return other;
    return values.firstWhere((type) => type.id == id, orElse: () => other);
  }

  static RequestTaskType fromLegacyTags(List<String> tags) {
    if (tags.contains(TtmRequestTags.moving)) return delivery;
    if (tags.contains(TtmRequestTags.document)) return other;
    return values.firstWhere(
      (type) => tags.contains(type.legacyTag),
      orElse: () => other,
    );
  }

  /// 찾기 탭에서 새 작업 유형을 기존 `tags` 기반 RPC 필터로 변환한다.
  /// 통합 전 요청도 빠지지 않도록 운반·문서 태그를 함께 조회한다.
  static List<String> browseTagsForIds(Iterable<String> ids) {
    final tags = <String>{};
    for (final id in ids) {
      final type = fromId(id);
      tags.add(type.legacyTag);
      if (type.id == delivery.id) tags.add(TtmRequestTags.moving);
      if (type.id == other.id) tags.add(TtmRequestTags.document);
    }
    return tags.toList(growable: false);
  }
}

class RequestTaskPolicy {
  const RequestTaskPolicy({required this.type, required this.options});

  final RequestTaskType type;
  final Map<String, dynamic> options;

  bool get allowsStationaryWorker => type.id == RequestTaskType.waiting.id;

  int? get waitingDurationMinutes => _positiveInt('waiting_duration_minutes');

  int? get proofIntervalMinutes => _positiveInt('proof_interval_minutes');

  int? _positiveInt(String key) {
    final raw = options[key];
    final value = raw is num ? raw.toInt() : int.tryParse('$raw');
    return value != null && value > 0 ? value : null;
  }
}
