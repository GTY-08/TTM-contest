import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/push/push_flush.dart';
import '../models/exercise_matching_models.dart';
import '../models/raid_models.dart';

class RaidRepository {
  RaidRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<ExerciseVenue>> fetchVenues() async {
    final raw = await _supabase.rpc('list_exercise_venues');
    return _mapList(raw, ExerciseVenue.fromMap);
  }

  Future<List<Raid>> fetchRaids({
    double? latitude,
    double? longitude,
    int? radiusM,
    String? exerciseType,
    String? feeType,
    int limit = 30,
    DateTime? cursorStartsAt,
    String? cursorId,
  }) async {
    final raw = await _supabase.rpc(
      'list_raids',
      params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_m': radiusM,
        'p_exercise_type': exerciseType,
        'p_fee_type': feeType,
        'p_limit': limit,
        'p_cursor_starts_at': cursorStartsAt?.toUtc().toIso8601String(),
        'p_cursor_id': cursorId,
      },
    );
    return _mapList(raw, Raid.fromMap);
  }

  Future<List<Raid>> fetchMyRaids() async {
    final raw = await _supabase.rpc('list_my_raids');
    return _mapList(raw, Raid.fromMap);
  }

  Future<RaidDetail> fetchDetail(String raidId) async {
    final raw = await _supabase.rpc(
      'get_raid_detail',
      params: {'p_raid_id': raidId},
    );
    if (raw is! Map) throw StateError('raid_not_found');
    return RaidDetail.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<Map<String, dynamic>> createPremiumRaid({
    required String venueId,
    required String exerciseType,
    required String title,
    required String description,
    required DateTime startsAt,
    required int durationMinutes,
    required int minParticipants,
    required int maxParticipants,
    required String intensity,
    required bool beginnerFriendly,
    required int participationFee,
  }) => _rpc('create_premium_raid', {
    'p_venue_id': venueId,
    'p_exercise_type': exerciseType,
    'p_title': title,
    'p_description': description,
    'p_starts_at': startsAt.toUtc().toIso8601String(),
    'p_duration_minutes': durationMinutes,
    'p_min_participants': minParticipants,
    'p_max_participants': maxParticipants,
    'p_intensity': intensity,
    'p_beginner_friendly': beginnerFriendly,
    'p_participation_fee': participationFee,
  });

  Future<Map<String, dynamic>> checkRaidEligibility(
    String raidId,
    ExerciseLocationSnapshot location,
  ) => _rpc('get_raid_join_eligibility', {
    'p_raid_id': raidId,
    ..._locationParams(location),
  });

  Future<Map<String, dynamic>> joinFree(
    String raidId,
    ExerciseLocationSnapshot location,
  ) => _rpc('join_free_raid_nearby', {
    'p_raid_id': raidId,
    ..._locationParams(location),
  });

  Future<Map<String, dynamic>> applyPremium(
    String raidId,
    ExerciseLocationSnapshot location, {
    String? message,
  }) => _rpc('apply_premium_raid_nearby', {
    'p_raid_id': raidId,
    'p_message': message,
    ..._locationParams(location),
  });

  Future<ExercisePreferences> fetchExercisePreferences() async {
    final raw = await _supabase.rpc('get_my_exercise_preferences');
    if (raw is! Map) throw StateError('preferences_unavailable');
    return ExercisePreferences.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<Map<String, dynamic>> saveExercisePreferences({
    required String? activityLabel,
    required double? latitude,
    required double? longitude,
    required List<String> exercises,
    required String fitnessLevel,
    required List<int> availableDays,
    required String availableStart,
    required String availableEnd,
    required int maxDistanceMeters,
  }) => _rpc('upsert_my_exercise_preferences', {
    'p_activity_label': activityLabel,
    'p_lat': latitude,
    'p_lng': longitude,
    'p_preferred_exercises': exercises,
    'p_fitness_level': fitnessLevel,
    'p_available_days': availableDays,
    'p_available_start': availableStart,
    'p_available_end': availableEnd,
    'p_max_distance_m': maxDistanceMeters,
  });

  Future<Map<String, dynamic>> setExerciseAvailability({
    required bool online,
    ExerciseLocationSnapshot? location,
    required int maxDistanceMeters,
    required List<String> exerciseTypes,
  }) async {
    final result = await _rpc('set_exercise_match_availability', {
      'p_online': online,
      'p_lat': location?.latitude,
      'p_lng': location?.longitude,
      'p_accuracy_m': location?.accuracyMeters,
      'p_captured_at': location?.capturedAt.toUtc().toIso8601String(),
      'p_max_distance_m': maxDistanceMeters,
      'p_exercise_types': exerciseTypes,
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<Map<String, dynamic>> createQuickMatch({
    required String meetingSource,
    String? venueId,
    required String meetingLabel,
    required String exerciseType,
    required int durationMinutes,
    required String intensity,
    required String partnerLevelPreference,
    required int maxDistanceMeters,
    required ExerciseLocationSnapshot location,
  }) async {
    final result = await _rpc('create_exercise_quick_match', {
      'p_meeting_source': meetingSource,
      'p_venue_id': venueId,
      'p_meeting_label': meetingLabel,
      'p_exercise_type': exerciseType,
      'p_duration_minutes': durationMinutes,
      'p_intensity': intensity,
      'p_partner_level_pref': partnerLevelPreference,
      'p_max_distance_m': maxDistanceMeters,
      ..._locationParams(location),
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<Map<String, dynamic>> advanceQuickMatch(String quickMatchId) async {
    final result = await _rpc('advance_exercise_quick_match', {
      'p_quick_match_id': quickMatchId,
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<ExerciseQuickMatch?> fetchMyQuickMatch() async {
    final raw = await _supabase.rpc('get_my_exercise_quick_match');
    if (raw is! Map) return null;
    return ExerciseQuickMatch.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<List<ExerciseMatchOffer>> fetchQuickMatchOffers() async {
    final raw = await _supabase.rpc('list_my_exercise_match_offers');
    return _mapList(raw, ExerciseMatchOffer.fromMap);
  }

  Future<Map<String, dynamic>> respondQuickMatchOffer({
    required String offerId,
    required bool accept,
    ExerciseLocationSnapshot? location,
  }) async {
    final result = await _rpc('respond_exercise_match_offer', {
      'p_offer_id': offerId,
      'p_accept': accept,
      'p_lat': location?.latitude,
      'p_lng': location?.longitude,
      'p_accuracy_m': location?.accuracyMeters,
      'p_captured_at': location?.capturedAt.toUtc().toIso8601String(),
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<Map<String, dynamic>> cancelQuickMatch(String quickMatchId) =>
      _rpc('cancel_exercise_quick_match', {'p_quick_match_id': quickMatchId});

  Future<Map<String, dynamic>> completeQuickMatch(String quickMatchId) =>
      _rpc('complete_exercise_quick_match', {'p_quick_match_id': quickMatchId});

  Stream<List<Map<String, dynamic>>> watchQuickMessages(String quickMatchId) {
    return _supabase
        .from('exercise_match_messages')
        .stream(primaryKey: ['id'])
        .eq('quick_match_id', quickMatchId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false),
        );
  }

  Future<void> sendQuickMessage(String quickMatchId, String content) async {
    final uid = _supabase.auth.currentUser?.id;
    final clean = content.trim();
    if (uid == null) throw StateError('not_authenticated');
    if (clean.isEmpty) return;
    await _supabase.from('exercise_match_messages').insert({
      'quick_match_id': quickMatchId,
      'sender_id': uid,
      'content': clean,
    });
  }

  Future<Map<String, dynamic>> startRaidRecruitment({
    required String raidId,
    required String fillGoal,
    required String approvalMode,
  }) async {
    final result = await _rpc('start_raid_recruitment', {
      'p_raid_id': raidId,
      'p_fill_goal': fillGoal,
      'p_approval_mode': approvalMode,
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<Map<String, dynamic>> advanceRaidRecruitment(String campaignId) async {
    final result = await _rpc('advance_raid_recruitment', {
      'p_campaign_id': campaignId,
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<RaidRecruitmentCampaign?> fetchRaidRecruitment(String raidId) async {
    final raw = await _supabase.rpc(
      'get_raid_recruitment_status',
      params: {'p_raid_id': raidId},
    );
    if (raw is! Map) return null;
    return RaidRecruitmentCampaign.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<List<RaidRecruitmentOffer>> fetchRaidRecruitmentOffers() async {
    final raw = await _supabase.rpc('list_my_raid_recruitment_offers');
    return _mapList(raw, RaidRecruitmentOffer.fromMap);
  }

  Future<Map<String, dynamic>> respondRaidRecruitmentOffer({
    required String offerId,
    required bool accept,
    ExerciseLocationSnapshot? location,
  }) async {
    final result = await _rpc('respond_raid_recruitment_offer', {
      'p_offer_id': offerId,
      'p_accept': accept,
      'p_lat': location?.latitude,
      'p_lng': location?.longitude,
      'p_accuracy_m': location?.accuracyMeters,
      'p_captured_at': location?.capturedAt.toUtc().toIso8601String(),
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<Map<String, dynamic>> reviewApplication(
    String participantId,
    String decision,
  ) => _rpc('review_raid_application', {
    'p_participant_id': participantId,
    'p_decision': decision,
  });

  Future<Map<String, dynamic>> leave(String raidId) =>
      _rpc('leave_raid', {'p_raid_id': raidId});

  Future<Map<String, dynamic>> recordAttendance(
    String participantId,
    String status,
  ) => _rpc('record_raid_attendance', {
    'p_participant_id': participantId,
    'p_status': status,
  });

  Future<Map<String, dynamic>> castAttendanceVote(
    String participantId,
    String vote,
  ) => _rpc('cast_attendance_vote', {
    'p_target_participant_id': participantId,
    'p_vote': vote,
  });

  Future<Map<String, dynamic>> appealAttendance(String raidId, String reason) =>
      _rpc('appeal_raid_attendance', {'p_raid_id': raidId, 'p_reason': reason});

  Future<Map<String, dynamic>> finalize(String raidId) =>
      _rpc('finalize_raid', {'p_raid_id': raidId});

  Future<Map<String, dynamic>> cancel(String raidId, String reason) =>
      _rpc('cancel_raid', {'p_raid_id': raidId, 'p_reason': reason});

  Stream<List<RaidMessage>> watchMessages(String raidId) {
    return _supabase
        .from('raid_messages')
        .stream(primaryKey: ['id'])
        .eq('raid_id', raidId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => RaidMessage.fromMap(Map<String, dynamic>.from(row)))
              .toList(growable: false),
        );
  }

  Future<void> sendMessage(String raidId, String content) async {
    final uid = _supabase.auth.currentUser?.id;
    final clean = content.trim();
    if (uid == null) throw StateError('not_authenticated');
    if (clean.isEmpty) return;
    await _supabase.from('raid_messages').insert({
      'raid_id': raidId,
      'sender_id': uid,
      'content': clean,
    });
  }

  Future<void> markChatRead(String raidId) =>
      _supabase.rpc('mark_raid_chat_read', params: {'p_raid_id': raidId});

  Future<RewardSummary> fetchRewardSummary() async {
    final raw = await _supabase.rpc('get_my_reward_summary');
    if (raw is! Map) throw StateError('reward_summary_unavailable');
    return RewardSummary.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<Map<String, dynamic>> redeemReward(String itemId) =>
      _rpc('redeem_reward', {'p_catalog_item_id': itemId});

  Future<Map<String, dynamic>> fetchFeeWallet() async {
    final raw = await _supabase.rpc('get_my_demo_wallet');
    final result = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final transactions = await _supabase
        .from('raid_fee_transactions')
        .select()
        .order('created_at', ascending: false)
        .limit(30);
    result['raid_fee_transactions'] = transactions;
    return result;
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final raw = await _supabase.rpc(name, params: params);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic>) fromMap) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Map<String, dynamic> _locationParams(ExerciseLocationSnapshot location) => {
    'p_lat': location.latitude,
    'p_lng': location.longitude,
    'p_accuracy_m': location.accuracyMeters,
    'p_captured_at': location.capturedAt.toUtc().toIso8601String(),
  };
}
