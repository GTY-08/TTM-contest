import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/push/push_flush.dart';
import '../../../data/repositories/chat_attachment_repository.dart';
import '../../chat/models/chat_message.dart';
import '../models/exercise_matching_models.dart';
import '../models/raid_models.dart';

class RaidRepository {
  RaidRepository(this._supabase, {ChatAttachmentRepository? attachments})
    : _attachments = attachments ?? ChatAttachmentRepository(_supabase);

  final SupabaseClient _supabase;
  final ChatAttachmentRepository _attachments;

  Future<List<ExerciseVenue>> fetchVenues() async {
    final raw = await _supabase.rpc('list_exercise_venues');
    return _mapList(raw, ExerciseVenue.fromMap);
  }

  Future<List<RaidPlaceSearchResult>> searchPlaces(String query) async {
    final response = await _supabase.functions.invoke(
      'place-search',
      body: {'q': query.trim()},
    );
    final data = response.data;
    if (data is! Map) throw StateError('place_search_unavailable');
    final map = Map<String, dynamic>.from(data);
    if (map['ok'] != true) {
      throw StateError(map['reason']?.toString() ?? 'place_search_failed');
    }
    final items = map['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              RaidPlaceSearchResult.fromMap(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.hasValidLocation && item.label.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Raid>> fetchRaids({
    double? latitude,
    double? longitude,
    int? radiusM,
    String? exerciseType,
    String? feeType,
    int limit = 2,
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
    required String locationName,
    required String locationAddress,
    required double latitude,
    required double longitude,
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
    'p_location_name': locationName,
    'p_location_address': locationAddress,
    'p_lat': latitude,
    'p_lng': longitude,
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
  ) async {
    final result = await _rpc('join_free_raid_nearby', {
      'p_raid_id': raidId,
      ..._locationParams(location),
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<Map<String, dynamic>> applyPremium(
    String raidId,
    ExerciseLocationSnapshot location, {
    String? message,
  }) async {
    final result = await _rpc('apply_premium_raid_nearby', {
      'p_raid_id': raidId,
      'p_message': message,
      ..._locationParams(location),
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

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

  Stream<({List<ChatMessage> messages, ChatReadState reads})>
  watchQuickMessages(String quickMatchId) {
    Future<({List<ChatMessage> messages, ChatReadState reads})> load() async {
      final rows = await _supabase
          .from('exercise_match_messages')
          .select()
          .eq('quick_match_id', quickMatchId)
          .order('created_at', ascending: true);
      final messages =
          rows
              .map((row) {
                final map = Map<String, dynamic>.from(row);
                map['request_id'] = quickMatchId;
                return ChatMessage.fromMap(map);
              })
              .toList(growable: false)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return (
        messages: messages,
        reads: await _fetchQuickMatchReadState(quickMatchId),
      );
    }

    final controller =
        StreamController<({List<ChatMessage> messages, ChatReadState reads})>();
    StreamSubscription<dynamic>? messageSubscription;
    StreamSubscription<dynamic>? readSubscription;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        controller.add(await load());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () {
      unawaited(emit());
      messageSubscription = _supabase
          .from('exercise_match_messages')
          .stream(primaryKey: ['id'])
          .eq('quick_match_id', quickMatchId)
          .listen((_) => unawaited(emit()));
      readSubscription = _supabase
          .from('exercise_quick_match_reads')
          .stream(primaryKey: ['quick_match_id', 'user_id'])
          .eq('quick_match_id', quickMatchId)
          .listen((_) => unawaited(emit()));
    };
    controller.onCancel = () async {
      await messageSubscription?.cancel();
      await readSubscription?.cancel();
    };
    return controller.stream;
  }

  Future<ChatReadState> _fetchQuickMatchReadState(String quickMatchId) async {
    final raw = await _supabase.rpc(
      'get_exercise_quick_match_read_state',
      params: {'p_quick_match_id': quickMatchId},
    );
    if (raw is! Map) return const ChatReadState();
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) return const ChatReadState();
    return ChatReadState(
      myLastReadAt: DateTime.tryParse(map['my_last_read_at']?.toString() ?? ''),
      counterpartLastReadAt: DateTime.tryParse(
        map['counterpart_last_read_at']?.toString() ?? '',
      ),
    );
  }

  Future<Map<String, dynamic>> sendQuickMessage(
    String quickMatchId,
    String content,
  ) async {
    final result = await _rpc('send_exercise_quick_match_message', {
      'p_quick_match_id': quickMatchId,
      'p_content': content.trim(),
      'p_message_type': 'text',
      'p_attachment_url': null,
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<void> sendQuickImageMessages({
    required String quickMatchId,
    required List<File> files,
  }) async {
    for (final file in files) {
      final url = await _attachments.uploadExerciseQuickMatchImage(
        quickMatchId: quickMatchId,
        file: file,
      );
      final result = await _rpc('send_exercise_quick_match_message', {
        'p_quick_match_id': quickMatchId,
        'p_content': '',
        'p_message_type': 'image',
        'p_attachment_url': url,
      });
      if (result['ok'] != true) {
        throw StateError(result['reason']?.toString() ?? 'message_send_failed');
      }
    }
    await flushPushOutbox(_supabase);
  }

  Future<void> markQuickMatchChatRead(String quickMatchId) => _supabase.rpc(
    'mark_exercise_quick_match_chat_read',
    params: {'p_quick_match_id': quickMatchId},
  );

  Stream<List<ExerciseQuickMatchLocation>> watchQuickMatchLocations(
    String quickMatchId,
  ) => _supabase
      .from('exercise_quick_match_locations')
      .stream(primaryKey: ['quick_match_id', 'user_id'])
      .eq('quick_match_id', quickMatchId)
      .map(
        (rows) => rows
            .map(
              (row) => ExerciseQuickMatchLocation.fromMap(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(growable: false),
      );

  Future<Map<String, dynamic>> updateQuickMatchLocation({
    required String quickMatchId,
    required ExerciseLocationSnapshot location,
  }) => _rpc('update_exercise_quick_match_location', {
    'p_quick_match_id': quickMatchId,
    ..._locationParams(location),
  });

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
  ) async {
    final result = await _rpc('review_raid_application', {
      'p_participant_id': participantId,
      'p_decision': decision,
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<Map<String, dynamic>> leave(String raidId) async {
    final result = await _rpc('leave_raid', {'p_raid_id': raidId});
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

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

  Stream<({List<ChatMessage> messages, ChatReadState reads})>
  watchApplicationMessages(String participantId) {
    Future<({List<ChatMessage> messages, ChatReadState reads})> load() async {
      final rows = await _supabase
          .from('raid_application_messages')
          .select()
          .eq('participant_id', participantId)
          .order('created_at', ascending: true);
      final messages =
          rows
              .map((row) {
                final map = Map<String, dynamic>.from(row);
                map['request_id'] = participantId;
                return ChatMessage.fromMap(map);
              })
              .toList(growable: false)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final reads = await _fetchApplicationReadState(participantId);
      return (messages: messages, reads: reads);
    }

    final controller =
        StreamController<({List<ChatMessage> messages, ChatReadState reads})>();
    StreamSubscription<dynamic>? messageSubscription;
    StreamSubscription<dynamic>? readSubscription;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        controller.add(await load());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () {
      unawaited(emit());
      messageSubscription = _supabase
          .from('raid_application_messages')
          .stream(primaryKey: ['id'])
          .eq('participant_id', participantId)
          .listen((_) => unawaited(emit()));
      readSubscription = _supabase
          .from('raid_application_reads')
          .stream(primaryKey: ['participant_id', 'user_id'])
          .eq('participant_id', participantId)
          .listen((_) => unawaited(emit()));
    };

    controller.onCancel = () async {
      await messageSubscription?.cancel();
      await readSubscription?.cancel();
    };
    return controller.stream;
  }

  Future<ChatReadState> _fetchApplicationReadState(String participantId) async {
    final raw = await _supabase.rpc(
      'get_raid_application_read_state',
      params: {'p_participant_id': participantId},
    );
    if (raw is! Map) return const ChatReadState();
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) return const ChatReadState();
    return ChatReadState(
      myLastReadAt: DateTime.tryParse(map['my_last_read_at']?.toString() ?? ''),
      counterpartLastReadAt: DateTime.tryParse(
        map['counterpart_last_read_at']?.toString() ?? '',
      ),
    );
  }

  Future<Map<String, dynamic>> sendApplicationMessage({
    required String participantId,
    required String content,
  }) async {
    final result = await _rpc('send_raid_application_message', {
      'p_participant_id': participantId,
      'p_content': content.trim(),
      'p_message_type': 'text',
      'p_attachment_url': null,
    });
    if (result['ok'] == true) await flushPushOutbox(_supabase);
    return result;
  }

  Future<void> sendApplicationImageMessages({
    required String participantId,
    required List<File> files,
  }) async {
    for (final file in files) {
      final url = await _attachments.uploadRaidApplicationImage(
        participantId: participantId,
        file: file,
      );
      final result = await _rpc('send_raid_application_message', {
        'p_participant_id': participantId,
        'p_content': '',
        'p_message_type': 'image',
        'p_attachment_url': url,
      });
      if (result['ok'] != true) {
        throw StateError(result['reason']?.toString() ?? 'message_send_failed');
      }
    }
    await flushPushOutbox(_supabase);
  }

  Future<void> markApplicationChatRead(String participantId) => _supabase.rpc(
    'mark_raid_application_chat_read',
    params: {'p_participant_id': participantId},
  );

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
