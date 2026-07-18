import 'package:flutter/foundation.dart';

@immutable
class ExercisePreferences {
  const ExercisePreferences({
    required this.preferredExercises,
    required this.fitnessLevel,
    required this.availableDays,
    required this.availableStart,
    required this.availableEnd,
    required this.maxDistanceMeters,
    this.activityLabel,
    this.latitude,
    this.longitude,
  });

  final String? activityLabel;
  final double? latitude;
  final double? longitude;
  final List<String> preferredExercises;
  final String fitnessLevel;
  final List<int> availableDays;
  final String availableStart;
  final String availableEnd;
  final int maxDistanceMeters;

  factory ExercisePreferences.fromMap(Map<String, dynamic> map) =>
      ExercisePreferences(
        activityLabel: map['activity_label']?.toString(),
        latitude: _doubleOrNull(map['latitude']),
        longitude: _doubleOrNull(map['longitude']),
        preferredExercises: _strings(map['preferred_exercises']),
        fitnessLevel: map['fitness_level']?.toString() ?? 'beginner',
        availableDays: _ints(map['available_days']),
        availableStart: map['available_start']?.toString() ?? '06:00',
        availableEnd: map['available_end']?.toString() ?? '22:00',
        maxDistanceMeters: _int(map['max_distance_m'], 5000),
      );
}

@immutable
class ExerciseQuickMatch {
  const ExerciseQuickMatch({
    required this.id,
    required this.requesterId,
    required this.meetingSource,
    required this.meetingLabel,
    required this.exerciseType,
    required this.durationMinutes,
    required this.intensity,
    required this.partnerLevelPreference,
    required this.maxDistanceMeters,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.currentStage,
    required this.expiresAt,
    this.matchedUserId,
    this.meetingVenueId,
    this.latitude,
    this.longitude,
    this.partner,
  });

  final String id;
  final String requesterId;
  final String? matchedUserId;
  final String meetingSource;
  final String? meetingVenueId;
  final String meetingLabel;
  final double? latitude;
  final double? longitude;
  final String exerciseType;
  final int durationMinutes;
  final String intensity;
  final String partnerLevelPreference;
  final int maxDistanceMeters;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final int currentStage;
  final DateTime expiresAt;
  final Map<String, dynamic>? partner;

  bool get isSearching => status == 'searching';
  bool get isMatched => status == 'matched' || status == 'in_progress';

  factory ExerciseQuickMatch.fromMap(Map<String, dynamic> map) =>
      ExerciseQuickMatch(
        id: map['id']?.toString() ?? '',
        requesterId: map['requester_id']?.toString() ?? '',
        matchedUserId: map['matched_user_id']?.toString(),
        meetingSource: map['meeting_source']?.toString() ?? 'current',
        meetingVenueId: map['meeting_venue_id']?.toString(),
        meetingLabel: map['meeting_label']?.toString() ?? '현재 위치 근처',
        latitude: _doubleOrNull(map['latitude']),
        longitude: _doubleOrNull(map['longitude']),
        exerciseType: map['exercise_type']?.toString() ?? 'walking',
        durationMinutes: _int(map['duration_minutes'], 30),
        intensity: map['intensity']?.toString() ?? 'medium',
        partnerLevelPreference:
            map['partner_level_pref']?.toString() ?? 'similar',
        maxDistanceMeters: _int(map['max_distance_m'], 3000),
        startsAt: _date(map['starts_at']),
        endsAt: _date(map['ends_at']),
        status: map['status']?.toString() ?? 'searching',
        currentStage: _int(map['current_stage'], 0),
        expiresAt: _date(map['expires_at']),
        partner: map['partner'] is Map
            ? Map<String, dynamic>.from(map['partner'] as Map)
            : null,
      );
}

@immutable
class ExerciseMatchOffer {
  const ExerciseMatchOffer({
    required this.id,
    required this.quickMatchId,
    required this.distanceMeters,
    required this.score,
    required this.expiresAt,
    required this.meetingLabel,
    required this.exerciseType,
    required this.durationMinutes,
    required this.intensity,
    this.requester,
  });

  final String id;
  final String quickMatchId;
  final int distanceMeters;
  final double score;
  final DateTime expiresAt;
  final String meetingLabel;
  final String exerciseType;
  final int durationMinutes;
  final String intensity;
  final Map<String, dynamic>? requester;

  factory ExerciseMatchOffer.fromMap(Map<String, dynamic> map) =>
      ExerciseMatchOffer(
        id: map['id']?.toString() ?? '',
        quickMatchId: map['quick_match_id']?.toString() ?? '',
        distanceMeters: _int(map['distance_m'], 0),
        score: _doubleOrNull(map['match_score']) ?? 0,
        expiresAt: _date(map['expires_at']),
        meetingLabel: map['meeting_label']?.toString() ?? '',
        exerciseType: map['exercise_type']?.toString() ?? 'walking',
        durationMinutes: _int(map['duration_minutes'], 30),
        intensity: map['intensity']?.toString() ?? 'medium',
        requester: map['requester'] is Map
            ? Map<String, dynamic>.from(map['requester'] as Map)
            : null,
      );
}

@immutable
class RaidRecruitmentCampaign {
  const RaidRecruitmentCampaign({
    required this.id,
    required this.raidId,
    required this.fillGoal,
    required this.targetParticipants,
    required this.approvalMode,
    required this.status,
    required this.currentStage,
    required this.offerCount,
    required this.acceptedCount,
  });

  final String id;
  final String raidId;
  final String fillGoal;
  final int targetParticipants;
  final String approvalMode;
  final String status;
  final int currentStage;
  final int offerCount;
  final int acceptedCount;

  factory RaidRecruitmentCampaign.fromMap(Map<String, dynamic> map) =>
      RaidRecruitmentCampaign(
        id: map['id']?.toString() ?? '',
        raidId: map['raid_id']?.toString() ?? '',
        fillGoal: map['fill_goal']?.toString() ?? 'minimum',
        targetParticipants: _int(map['target_participants'], 0),
        approvalMode: map['approval_mode']?.toString() ?? 'manual',
        status: map['status']?.toString() ?? 'recruiting',
        currentStage: _int(map['current_stage'], 0),
        offerCount: _int(map['offer_count'], 0),
        acceptedCount: _int(map['accepted_count'], 0),
      );
}

@immutable
class RaidRecruitmentOffer {
  const RaidRecruitmentOffer({
    required this.id,
    required this.campaignId,
    required this.raidId,
    required this.distanceMeters,
    required this.expiresAt,
    required this.title,
    required this.exerciseType,
    required this.startsAt,
    required this.participationFee,
    required this.venueName,
    required this.approvalMode,
  });

  final String id;
  final String campaignId;
  final String raidId;
  final int? distanceMeters;
  final DateTime expiresAt;
  final String title;
  final String exerciseType;
  final DateTime startsAt;
  final int participationFee;
  final String venueName;
  final String approvalMode;

  factory RaidRecruitmentOffer.fromMap(Map<String, dynamic> map) =>
      RaidRecruitmentOffer(
        id: map['id']?.toString() ?? '',
        campaignId: map['campaign_id']?.toString() ?? '',
        raidId: map['raid_id']?.toString() ?? '',
        distanceMeters: map['distance_m'] == null
            ? null
            : _int(map['distance_m'], 0),
        expiresAt: _date(map['expires_at']),
        title: map['title']?.toString() ?? '운동 레이드',
        exerciseType: map['exercise_type']?.toString() ?? 'walking',
        startsAt: _date(map['starts_at']),
        participationFee: _int(map['participation_fee'], 0),
        venueName: map['venue_name']?.toString() ?? '',
        approvalMode: map['approval_mode']?.toString() ?? 'instant',
      );
}

@immutable
class ExerciseLocationSnapshot {
  const ExerciseLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

List<String> _strings(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];

List<int> _ints(Object? value) => value is List
    ? value.map((item) => _int(item, 0)).where((item) => item > 0).toList()
    : const [];
