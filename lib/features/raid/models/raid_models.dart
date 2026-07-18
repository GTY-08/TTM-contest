import 'package:flutter/foundation.dart';

const raidDiscoveryWindow = Duration(hours: 6);
const raidMinimumLeadTime = Duration(minutes: 10);

@immutable
class ExerciseVenue {
  const ExerciseVenue({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.supportedExercises,
    required this.defaultDurationMinutes,
    required this.recommendedMinParticipants,
    required this.maxParticipants,
    required this.defaultIntensity,
    required this.beginnerFriendly,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> supportedExercises;
  final int defaultDurationMinutes;
  final int recommendedMinParticipants;
  final int maxParticipants;
  final String defaultIntensity;
  final bool beginnerFriendly;

  factory ExerciseVenue.fromMap(Map<String, dynamic> map) => ExerciseVenue(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    address: map['address']?.toString() ?? '',
    latitude: _asDouble(map['latitude']),
    longitude: _asDouble(map['longitude']),
    supportedExercises: _asStringList(map['supported_exercises']),
    defaultDurationMinutes: _asInt(map['default_duration_minutes'], 60),
    recommendedMinParticipants: _asInt(map['recommended_min_participants'], 3),
    maxParticipants: _asInt(map['max_participants'], 12),
    defaultIntensity: map['default_intensity']?.toString() ?? 'medium',
    beginnerFriendly: map['beginner_friendly'] != false,
  );
}

@immutable
class RaidPlaceSearchResult {
  const RaidPlaceSearchResult({
    required this.label,
    required this.address,
    required this.source,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final String address;
  final String source;
  final double latitude;
  final double longitude;

  factory RaidPlaceSearchResult.fromMap(Map<String, dynamic> map) {
    final name = map['name']?.toString().trim() ?? '';
    final road = map['roadAddress']?.toString().trim() ?? '';
    final jibun = map['jibunAddress']?.toString().trim() ?? '';
    return RaidPlaceSearchResult(
      label: name.isNotEmpty ? name : (road.isNotEmpty ? road : jibun),
      address: road.isNotEmpty ? road : jibun,
      source: map['source']?.toString() ?? '',
      latitude: _asDouble(map['lat']),
      longitude: _asDouble(map['lng']),
    );
  }

  bool get hasValidLocation =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      (latitude != 0 || longitude != 0);
}

@immutable
class RaidLiveLocation {
  const RaidLiveLocation({
    required this.raidId,
    required this.participantId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
  });

  final String raidId;
  final String participantId;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime capturedAt;

  bool get isFresh =>
      capturedAt.isAfter(DateTime.now().subtract(const Duration(minutes: 5)));

  factory RaidLiveLocation.fromMap(Map<String, dynamic> map) =>
      RaidLiveLocation(
        raidId: map['raid_id']?.toString() ?? '',
        participantId: map['participant_id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        latitude: _asDouble(map['latitude']),
        longitude: _asDouble(map['longitude']),
        accuracyMeters: _asNullableDouble(map['accuracy_m']),
        capturedAt:
            DateTime.tryParse(
              map['captured_at']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

@immutable
class RaidParticipant {
  const RaidParticipant({
    required this.id,
    required this.userId,
    required this.role,
    required this.status,
    required this.paymentStatus,
    required this.attendanceStatus,
    this.nickname,
    this.profileImageUrl,
    this.applicationMessage,
    this.rating,
    this.isPremium = false,
  });

  final String id;
  final String userId;
  final String role;
  final String status;
  final String paymentStatus;
  final String attendanceStatus;
  final String? nickname;
  final String? profileImageUrl;
  final String? applicationMessage;
  final double? rating;
  final bool isPremium;

  bool get isOrganizer => role == 'organizer';
  bool get isApproved => status == 'approved';

  factory RaidParticipant.fromMap(Map<String, dynamic> map) => RaidParticipant(
    id: map['id']?.toString() ?? '',
    userId: map['user_id']?.toString() ?? '',
    role: map['role']?.toString() ?? 'member',
    status: map['status']?.toString() ?? 'applied',
    paymentStatus: map['payment_status']?.toString() ?? 'not_required',
    attendanceStatus: map['attendance_status']?.toString() ?? 'pending',
    nickname: map['nickname']?.toString(),
    profileImageUrl: map['profile_image_url']?.toString(),
    applicationMessage: map['application_message']?.toString(),
    rating: _asNullableDouble(map['rating']),
    isPremium: map['is_premium'] == true,
  );
}

@immutable
class Raid {
  const Raid({
    required this.id,
    required this.source,
    required this.exerciseType,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.durationMinutes,
    required this.minParticipants,
    required this.maxParticipants,
    required this.participantCount,
    required this.intensity,
    required this.beginnerFriendly,
    required this.participationFee,
    required this.status,
    required this.venue,
    this.organizerId,
    this.freeCancelAt,
    this.myParticipant,
    this.distanceMeters,
  });

  final String id;
  final String source;
  final String? organizerId;
  final String exerciseType;
  final String title;
  final String description;
  final DateTime startsAt;
  final int durationMinutes;
  final int minParticipants;
  final int maxParticipants;
  final int participantCount;
  final String intensity;
  final bool beginnerFriendly;
  final int participationFee;
  final DateTime? freeCancelAt;
  final String status;
  final ExerciseVenue venue;
  final RaidParticipant? myParticipant;
  final int? distanceMeters;

  bool get isFree => source == 'auto';
  bool get isPremiumRaid => source == 'premium';
  bool get isFull => participantCount >= maxParticipants;
  bool get isJoinable =>
      (status == 'recruiting' || status == 'confirmed') &&
      startsAt.isAfter(DateTime.now()) &&
      !isFull;
  bool get isMember => myParticipant?.isApproved ?? false;
  bool get isApplied =>
      myParticipant?.status == 'applied' ||
      myParticipant?.status == 'waitlisted';

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  factory Raid.fromMap(Map<String, dynamic> map) {
    final venueMap = Map<String, dynamic>.from(
      (map['venue'] as Map?) ?? const <String, dynamic>{},
    );
    final participantMap = map['my_participant'];
    return Raid(
      id: map['id']?.toString() ?? '',
      source: map['source']?.toString() ?? 'auto',
      organizerId: map['organizer_id']?.toString(),
      exerciseType: map['exercise_type']?.toString() ?? 'walking',
      title: map['title']?.toString() ?? '운동 레이드',
      description: map['description']?.toString() ?? '',
      startsAt:
          DateTime.tryParse(map['starts_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      durationMinutes: _asInt(map['duration_minutes'], 60),
      minParticipants: _asInt(map['min_participants'], 3),
      maxParticipants: _asInt(map['max_participants'], 12),
      participantCount: _asInt(map['participant_count'], 0),
      intensity: map['intensity']?.toString() ?? 'medium',
      beginnerFriendly: map['beginner_friendly'] != false,
      participationFee: _asInt(map['participation_fee'], 0),
      freeCancelAt: DateTime.tryParse(
        map['free_cancel_at']?.toString() ?? '',
      )?.toLocal(),
      status: map['status']?.toString() ?? 'recruiting',
      venue: ExerciseVenue.fromMap(venueMap),
      myParticipant: participantMap is Map
          ? RaidParticipant.fromMap(Map<String, dynamic>.from(participantMap))
          : null,
      distanceMeters: map['distance_m'] == null
          ? null
          : _asInt(map['distance_m'], 0),
    );
  }
}

@immutable
class RaidDetail {
  const RaidDetail({
    required this.raid,
    required this.participants,
    this.organizer,
  });

  final Raid raid;
  final List<RaidParticipant> participants;
  final Map<String, dynamic>? organizer;

  factory RaidDetail.fromMap(Map<String, dynamic> map) {
    final raidMap = Map<String, dynamic>.from(
      (map['raid'] as Map?) ?? const <String, dynamic>{},
    );
    raidMap['venue'] = map['venue'];
    raidMap['participant_count'] = map['participant_count'];
    raidMap['my_participant'] = map['my_participant'];
    return RaidDetail(
      raid: Raid.fromMap(raidMap),
      participants: ((map['participants'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => RaidParticipant.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      organizer: map['organizer'] is Map
          ? Map<String, dynamic>.from(map['organizer'] as Map)
          : null,
    );
  }
}

@immutable
class RaidApplicationChatContext {
  const RaidApplicationChatContext({
    required this.raidId,
    required this.raidTitle,
    required this.raidStatus,
    required this.isApplicant,
    required this.participant,
    required this.counterpart,
  });

  final String raidId;
  final String raidTitle;
  final String raidStatus;
  final bool isApplicant;
  final RaidParticipant participant;
  final Map<String, dynamic> counterpart;

  bool get isReadOnly =>
      {'rejected', 'cancelled'}.contains(participant.status) ||
      {'completed', 'cancelled'}.contains(raidStatus);

  factory RaidApplicationChatContext.fromMap(Map<String, dynamic> map) {
    if (map['ok'] != true) {
      throw StateError(map['reason']?.toString() ?? 'chat_context_unavailable');
    }
    final participant = map['participant'];
    final counterpart = map['counterpart'];
    if (participant is! Map || counterpart is! Map) {
      throw StateError('chat_context_incomplete');
    }
    return RaidApplicationChatContext(
      raidId: map['raid_id']?.toString() ?? '',
      raidTitle: map['raid_title']?.toString() ?? '',
      raidStatus: map['raid_status']?.toString() ?? '',
      isApplicant: map['is_applicant'] == true,
      participant: RaidParticipant.fromMap(
        Map<String, dynamic>.from(participant),
      ),
      counterpart: Map<String, dynamic>.from(counterpart),
    );
  }
}

@immutable
class RaidMessage {
  const RaidMessage({
    required this.id,
    required this.raidId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String raidId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  factory RaidMessage.fromMap(Map<String, dynamic> map) => RaidMessage(
    id: map['id']?.toString() ?? '',
    raidId: map['raid_id']?.toString() ?? '',
    senderId: map['sender_id']?.toString() ?? '',
    content: map['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

@immutable
class RaidApplicationMessage {
  const RaidApplicationMessage({
    required this.id,
    required this.participantId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String participantId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  factory RaidApplicationMessage.fromMap(Map<String, dynamic> map) =>
      RaidApplicationMessage(
        id: map['id']?.toString() ?? '',
        participantId: map['participant_id']?.toString() ?? '',
        senderId: map['sender_id']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

@immutable
class RewardCatalogItem {
  const RewardCatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.pointCost,
    required this.stock,
    required this.iconKey,
    required this.accentColor,
  });

  final String id;
  final String name;
  final String description;
  final int pointCost;
  final int stock;
  final String iconKey;
  final String accentColor;

  factory RewardCatalogItem.fromMap(Map<String, dynamic> map) =>
      RewardCatalogItem(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        pointCost: _asInt(map['point_cost'], 0),
        stock: _asInt(map['stock'], 0),
        iconKey: map['icon_key']?.toString() ?? 'gift',
        accentColor: map['accent_color']?.toString() ?? '#0B7A75',
      );
}

@immutable
class RewardSummary {
  const RewardSummary({
    required this.availablePoints,
    required this.lifetimePoints,
    required this.level,
    required this.levelTitle,
    required this.requiredPoints,
    required this.nextRequiredPoints,
    required this.catalog,
    required this.transactions,
    required this.redemptions,
  });

  final int availablePoints;
  final int lifetimePoints;
  final int level;
  final String levelTitle;
  final int requiredPoints;
  final int? nextRequiredPoints;
  final List<RewardCatalogItem> catalog;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> redemptions;

  double get levelProgress {
    final next = nextRequiredPoints;
    if (next == null || next <= requiredPoints) return 1;
    return ((lifetimePoints - requiredPoints) / (next - requiredPoints)).clamp(
      0,
      1,
    );
  }

  factory RewardSummary.fromMap(Map<String, dynamic> map) {
    final wallet = Map<String, dynamic>.from(
      (map['wallet'] as Map?) ?? const <String, dynamic>{},
    );
    final level = Map<String, dynamic>.from(
      (map['level'] as Map?) ?? const <String, dynamic>{},
    );
    return RewardSummary(
      availablePoints: _asInt(wallet['available_points'], 0),
      lifetimePoints: _asInt(wallet['lifetime_points'], 0),
      level: _asInt(level['level'], 1),
      levelTitle: level['title']?.toString() ?? '첫걸음',
      requiredPoints: _asInt(level['required_lifetime_points'], 0),
      nextRequiredPoints: level['next_required_points'] == null
          ? null
          : _asInt(level['next_required_points'], 0),
      catalog: ((map['catalog'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                RewardCatalogItem.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      transactions: ((map['transactions'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      redemptions: ((map['redemptions'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
    );
  }
}

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(Object? value) => _asNullableDouble(value) ?? 0;

double? _asNullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

String exerciseLabel(String id) => switch (id) {
  'running' => '러닝',
  'walking' => '걷기',
  'badminton' => '배드민턴',
  'basketball' => '농구',
  'fitness' => '기초 체력 운동',
  _ => id,
};

String intensityLabel(String id) => switch (id) {
  'low' => '가볍게',
  'high' => '높음',
  _ => '보통',
};

String raidStatusLabel(String id) => switch (id) {
  'scheduled' => '예정',
  'recruiting' => '모집 중',
  'confirmed' => '참가 확정',
  'in_progress' => '진행 중',
  'attendance' => '출석 확인',
  'completed' => '완료',
  'cancelled' => '취소',
  _ => id,
};
