import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/matching_constants.dart';
import '../../../core/constants/storage_constants.dart';
import '../../../core/moderation/text_moderation_guard.dart';
import '../../../core/push/push_flush.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/chat_attachment_repository.dart';
import '../../chat/models/chat_message.dart';
import '../models/general_request_applicant.dart';
import '../models/general_request_post.dart';
import '../models/match_request.dart';
import '../models/request_task_proof.dart';
import '../models/worker_notification.dart';

/// 요청 생성·매칭 단계 진행·수락 등 매칭 도메인의 Supabase 호출을 모은 얇은 래퍼.
///
/// 각 RPC 는 마이그레이션 `20260514000000_matching_engine.sql` 에 정의돼 있다.
class MatchingRepository {
  MatchingRepository(this._supabase)
    : _attachments = ChatAttachmentRepository(_supabase),
      _moderation = TextModerationGuard(_supabase);

  final SupabaseClient _supabase;
  final ChatAttachmentRepository _attachments;
  final TextModerationGuard _moderation;

  /// 단일 요청 행을 한 번만 가져온다. 매칭 화면 첫 진입에서 한 번 호출.
  Future<MatchRequest?> fetchRequest(String requestId) async {
    final row = await _supabase
        .from('requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();
    if (row == null) return null;
    return MatchRequest.fromMap(row);
  }

  /// 요청 생성 + 1단계 매칭 즉시 시작. (서버 함수가 트랜잭션 안에서 처리)
  Future<MatchRequest> createOpenRequest({
    String? title,
    required String description,
    required List<String> tags,
    required String taskType,
    Map<String, dynamic> taskOptions = const {},
    required num reward,
    num? rewardMax,
    required double latitude,
    required double longitude,
    required DateTime deadline,
    required int estimatedTaskMinutes,
    required int maxSearchRadiusM,
    String? notes,
    int stageIntervalSeconds = TtmMatchingConstants.defaultStageIntervalSeconds,
    String matchingMode = 'quick',
  }) async {
    await _moderation.ensureAllowedFields(
      contextType: matchingMode == 'general' ? 'general_post' : 'request_post',
      targetType: 'request',
      fields: {
        'title': title,
        'description': description,
        'tags': tags.join(', '),
        'notes': notes,
      },
    );

    final params = _createRequestParams(
      title: title,
      description: description,
      tags: tags,
      taskType: taskType,
      taskOptions: taskOptions,
      reward: reward,
      rewardMax: rewardMax,
      latitude: latitude,
      longitude: longitude,
      deadline: deadline,
      estimatedTaskMinutes: estimatedTaskMinutes,
      maxSearchRadiusM: maxSearchRadiusM,
      notes: notes,
      stageIntervalSeconds: stageIntervalSeconds,
      matchingMode: matchingMode,
    );
    Object? row;
    try {
      row = await _supabase.rpc('create_request_open', params: params);
    } on PostgrestException catch (e) {
      _debugPostgrest('create_request_open primary', e, params);
      if (!_isFunctionSignatureMiss(e)) rethrow;

      final withoutTaskConfig = Map<String, dynamic>.from(params)
        ..remove('p_task_type')
        ..remove('p_task_options');
      try {
        row = await _supabase.rpc(
          'create_request_open',
          params: withoutTaskConfig,
        );
      } on PostgrestException catch (e2) {
        _debugPostgrest(
          'create_request_open without_task_config',
          e2,
          withoutTaskConfig,
        );
        if (!_isFunctionSignatureMiss(e2) || matchingMode != 'quick') {
          throw StateError(
            matchingMode == 'general'
                ? 'general_matching_db_migration_required'
                : e2.message,
          );
        }

        final legacyQuick = Map<String, dynamic>.from(withoutTaskConfig)
          ..remove('p_title')
          ..remove('p_matching_mode')
          ..remove('p_reward_max');
        if (title != null && title.trim().isNotEmpty) {
          legacyQuick['p_description'] = '${title.trim()}\n\n$description';
        }
        try {
          row = await _supabase.rpc('create_request_open', params: legacyQuick);
        } on PostgrestException catch (e3) {
          _debugPostgrest('create_request_open legacy_quick', e3, legacyQuick);
          rethrow;
        }
      }
    }

    final request = MatchRequest.fromMap(Map<String, dynamic>.from(row as Map));
    await flushPushDelivery();
    return request;
  }

  Map<String, dynamic> _createRequestParams({
    String? title,
    required String description,
    required List<String> tags,
    required String taskType,
    required Map<String, dynamic> taskOptions,
    required num reward,
    num? rewardMax,
    required double latitude,
    required double longitude,
    required DateTime deadline,
    required int estimatedTaskMinutes,
    required int maxSearchRadiusM,
    String? notes,
    required int stageIntervalSeconds,
    required String matchingMode,
  }) {
    final params = <String, dynamic>{
      'p_description': description,
      'p_tags': tags,
      'p_task_type': taskType,
      'p_task_options': taskOptions,
      'p_reward': reward,
      'p_lng': longitude,
      'p_lat': latitude,
      'p_deadline': deadline.toUtc().toIso8601String(),
      'p_estimated_task_minutes': estimatedTaskMinutes,
      'p_max_search_radius_m': maxSearchRadiusM,
      'p_notes': notes,
      'p_stage_interval_seconds': stageIntervalSeconds,
      'p_matching_mode': matchingMode,
      'p_reward_max': rewardMax,
      'p_title': title,
    };
    return params;
  }

  bool _isFunctionSignatureMiss(PostgrestException e) {
    final text = '${e.code} ${e.message} ${e.details ?? ''}'.toLowerCase();
    return text.contains('pgrst202') ||
        text.contains('could not find the function') ||
        text.contains('schema cache');
  }

  void _debugPostgrest(
    String label,
    PostgrestException e,
    Map<String, dynamic> params,
  ) {
    final safeKeys = params.keys.toList()..sort();
    // Do not log user-entered descriptions or coordinates; keys are enough
    // to diagnose PostgREST function matching.
    // ignore: avoid_print
    print(
      '[matching_rpc] $label code=${e.code} message=${e.message} '
      'details=${e.details} hint=${e.hint} paramKeys=$safeKeys',
    );
  }

  Future<MatchRequest> updateGeneralRequestPost({
    required String requestId,
    required String title,
    required String description,
    required List<String> tags,
    required String taskType,
    Map<String, dynamic> taskOptions = const {},
    required num reward,
    required double latitude,
    required double longitude,
    required DateTime deadline,
    required int estimatedTaskMinutes,
  }) async {
    await _moderation.ensureAllowedFields(
      contextType: 'general_post',
      targetType: 'request',
      targetId: requestId,
      requestId: requestId,
      fields: {
        'title': title,
        'description': description,
        'tags': tags.join(', '),
      },
    );

    final row = await _supabase.rpc(
      'update_general_request_post',
      params: {
        'p_request_id': requestId,
        'p_title': title,
        'p_description': description,
        'p_tags': tags,
        'p_task_type': taskType,
        'p_task_options': taskOptions,
        'p_reward': reward,
        'p_lng': longitude,
        'p_lat': latitude,
        'p_deadline': deadline.toUtc().toIso8601String(),
        'p_estimated_task_minutes': estimatedTaskMinutes,
      },
    );
    final request = MatchRequest.fromMap(Map<String, dynamic>.from(row as Map));
    await flushPushDelivery();
    return request;
  }

  Future<UploadedGeneralPostImage> uploadGeneralPostImage({
    required String requestId,
    required File file,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final bytes = await file.readAsBytes();
    final lower = file.path.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        '$uid/$requestId/${DateTime.now().microsecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from(TtmStorageConstants.requestPostImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    final url = _supabase.storage
        .from(TtmStorageConstants.requestPostImagesBucket)
        .getPublicUrl(path);
    return UploadedGeneralPostImage(imageUrl: url, storagePath: path);
  }

  Future<void> replaceGeneralRequestImages({
    required String requestId,
    required List<Map<String, dynamic>> images,
  }) async {
    await _supabase.rpc(
      'replace_general_request_images',
      params: {'p_request_id': requestId, 'p_images': images},
    );
  }

  Future<GeneralRequestPostDetail> fetchGeneralRequestDetail(
    String requestId,
  ) async {
    final raw = await _supabase.rpc(
      'get_general_request_detail',
      params: {'p_request_id': requestId},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) throw StateError(map['reason']?.toString() ?? '');
    return GeneralRequestPostDetail.fromMap(map);
  }

  Future<List<GeneralRequestComment>> fetchGeneralRequestComments(
    String requestId,
  ) async {
    final raw = await _supabase.rpc(
      'list_general_request_comments',
      params: {'p_request_id': requestId},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) return const [];
    return ((map['items'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              GeneralRequestComment.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> addGeneralRequestComment({
    required String requestId,
    required String content,
  }) async {
    await _moderation.ensureAllowed(
      contextType: 'general_post_comment',
      text: content,
      targetType: 'request',
      targetId: requestId,
      requestId: requestId,
    );
    await _supabase.rpc(
      'add_general_request_comment',
      params: {'p_request_id': requestId, 'p_content': content},
    );
  }

  Future<void> deleteGeneralRequestComment(String commentId) async {
    await _supabase.rpc(
      'delete_general_request_comment',
      params: {'p_comment_id': commentId},
    );
  }

  Future<Map<String, dynamic>> deleteGeneralRequestPost(
    String requestId, {
    String? reason,
  }) async {
    final raw = await _supabase.rpc(
      'delete_general_request_post',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<void> reportGeneralRequestComment({
    required String commentId,
    required String category,
    String? description,
  }) async {
    if (description?.trim().isNotEmpty == true) {
      await _moderation.ensureAllowed(
        contextType: 'report_description',
        text: description!,
        targetType: 'request_post_comment',
        targetId: commentId,
      );
    }
    await _supabase.rpc(
      'report_general_request_comment',
      params: {
        'p_comment_id': commentId,
        'p_category': category,
        'p_description': description,
      },
    );
  }

  /// 한 요청을 다음 단계로 진행 + FCM outbox 발송(match-tick Edge).
  Future<Map<String, dynamic>> advanceStage(String requestId) async {
    return _invokeMatchTick(requestId: requestId);
  }

  /// push_outbox 적재 후 FCM 발송. create·활동 ON 직후 등에 호출.
  Future<void> flushPushDelivery() => flushPushOutbox(_supabase);

  /// match-tick Edge: stage 진행 + push_outbox → FCM.
  Future<Map<String, dynamic>> _invokeMatchTick({
    required String requestId,
  }) async {
    final res = await _supabase.functions.invoke(
      'match-tick',
      body: {'request_id': requestId},
    );
    final dynamic raw = res.data;

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (res.status != 200) {
      return {'ok': false, 'reason': 'edge_error', 'status': res.status};
    }
    return {'ok': true};
  }

  /// 작업자: 심부름 완료를 요청 (status 는 matched 유지).
  Future<Map<String, dynamic>> requestCompletion(String requestId) async {
    final raw = await _supabase.rpc(
      'request_completion',
      params: {'p_request_id': requestId},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  /// 요청자: 작업자 완료 요청을 확인 → completed (정산·에스크로는 이후).
  Future<Map<String, dynamic>> confirmCompletion(String requestId) async {
    final raw = await _supabase.rpc(
      'complete_request',
      params: {'p_request_id': requestId},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<Map<String, dynamic>> rejectCompletion(
    String requestId, {
    String? reason,
  }) async {
    final raw = await _supabase.rpc(
      'reject_completion',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<Map<String, dynamic>> autoCompleteRequestIfDue(
    String requestId,
  ) async {
    final raw = await _supabase.rpc(
      'auto_complete_request_if_due',
      params: {'p_request_id': requestId},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  /// 작업자가 수락. atomic FOR UPDATE + status 체크는 서버에서 처리.
  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    final raw = await _supabase.rpc(
      'accept_request',
      params: {'p_request_id': requestId},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<Map<String, dynamic>> applyGeneralRequest(
    String requestId, {
    String? initialMessage,
  }) async {
    if (initialMessage?.trim().isNotEmpty == true) {
      await _moderation.ensureAllowed(
        contextType: 'general_application_message',
        text: initialMessage!,
        targetType: 'request',
        targetId: requestId,
        requestId: requestId,
      );
    }
    final raw = await _supabase.rpc(
      'apply_general_request',
      params: {'p_request_id': requestId, 'p_initial_message': initialMessage},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<Map<String, dynamic>> selectGeneralRequestApplicant({
    required String requestId,
    required String workerId,
    num? negotiatedReward,
  }) async {
    final raw = await _supabase.rpc(
      'select_general_request_applicant',
      params: {
        'p_request_id': requestId,
        'p_worker_id': workerId,
        'p_negotiated_reward': negotiatedReward,
      },
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<Map<String, dynamic>> proposeGeneralApplicationReward({
    required String applicationId,
    required num reward,
  }) async {
    final raw = await _supabase.rpc(
      'propose_general_application_reward',
      params: {'p_application_id': applicationId, 'p_reward': reward},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<Map<String, dynamic>> acceptGeneralApplicationReward(
    String applicationId,
  ) async {
    final raw = await _supabase.rpc(
      'accept_general_application_reward',
      params: {'p_application_id': applicationId},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Stream<GeneralApplicationAgreement?> watchGeneralApplicationAgreement(
    String applicationId,
  ) {
    return _supabase
        .from('request_applications')
        .stream(primaryKey: ['id'])
        .eq('id', applicationId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return GeneralApplicationAgreement.fromMap(
            Map<String, dynamic>.from(rows.first),
          );
        });
  }

  Stream<void> watchGeneralRequestApplications(String requestId) {
    return _supabase
        .from('request_applications')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .map((_) {});
  }

  Stream<({List<ChatMessage> messages, ChatReadState reads})>
  watchGeneralApplicationMessagesWithReads(String applicationId) {
    Future<({List<ChatMessage> messages, ChatReadState reads})> load() async {
      final rows = await _supabase
          .from('request_application_messages')
          .select()
          .eq('application_id', applicationId)
          .order('created_at', ascending: true);
      final messages = rows
          .map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      final reads = await _fetchGeneralApplicationReadState(applicationId);
      return (messages: messages, reads: reads);
    }

    final controller =
        StreamController<({List<ChatMessage> messages, ChatReadState reads})>();
    StreamSubscription<dynamic>? msgSub;
    StreamSubscription<dynamic>? readSub;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        controller.add(await load());
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    controller.onListen = () {
      unawaited(emit());
      msgSub = _supabase
          .from('request_application_messages')
          .stream(primaryKey: ['id'])
          .eq('application_id', applicationId)
          .listen((_) => unawaited(emit()));
      readSub = _supabase
          .from('request_application_reads')
          .stream(primaryKey: ['application_id', 'user_id'])
          .eq('application_id', applicationId)
          .listen((_) => unawaited(emit()));
    };

    controller.onCancel = () async {
      await msgSub?.cancel();
      await readSub?.cancel();
    };

    return controller.stream;
  }

  Future<ChatReadState> _fetchGeneralApplicationReadState(
    String applicationId,
  ) async {
    final raw = await _supabase.rpc(
      'get_general_application_read_state',
      params: {'p_application_id': applicationId},
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

  Future<Map<String, dynamic>> sendGeneralApplicationMessage({
    required String applicationId,
    required String content,
  }) async {
    await _moderation.ensureAllowed(
      contextType: 'general_application_chat',
      text: content,
      targetType: 'request_application',
      targetId: applicationId,
    );
    final raw = await _supabase.rpc(
      'send_general_application_message',
      params: {
        'p_application_id': applicationId,
        'p_content': content,
        'p_message_type': 'text',
        'p_attachment_url': null,
      },
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<void> sendGeneralApplicationImageMessages({
    required String applicationId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return;
    for (final file in files) {
      final url = await _attachments.uploadGeneralApplicationImage(
        applicationId: applicationId,
        file: file,
      );
      await _supabase.rpc(
        'send_general_application_message',
        params: {
          'p_application_id': applicationId,
          'p_content': '',
          'p_message_type': 'image',
          'p_attachment_url': url,
        },
      );
    }
    await flushPushDelivery();
  }

  Future<void> deleteGeneralApplicationMessage(String messageId) async {
    try {
      await _supabase.rpc(
        'mark_general_application_message_deleted',
        params: {'p_message_id': messageId},
      );
    } on PostgrestException catch (e) {
      if (!_isMissingGeneralMessageDeleteRpc(e)) rethrow;
      await _supabase
          .from('request_application_messages')
          .update({
            'content': '삭제된 메시지입니다.',
            'message_type': 'text',
            'attachment_url': null,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', _supabase.auth.currentUser?.id ?? '');
    }
  }

  bool _isMissingGeneralMessageDeleteRpc(PostgrestException e) {
    final text = '${e.code} ${e.message} ${e.details ?? ''}'.toLowerCase();
    return text.contains('pgrst202') ||
        text.contains('could not find the function') ||
        text.contains('mark_general_application_message_deleted');
  }

  Future<void> markGeneralApplicationChatRead(String applicationId) async {
    await _supabase.rpc(
      'mark_general_application_chat_read',
      params: {'p_application_id': applicationId},
    );
  }

  Future<Map<String, dynamic>> withdrawGeneralRequestApplication(
    String applicationId,
  ) async {
    final raw = await _supabase.rpc(
      'withdraw_general_request_application',
      params: {'p_application_id': applicationId},
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<List<GeneralRequestApplicant>> listGeneralRequestApplicants(
    String requestId,
  ) async {
    final raw = await _supabase.rpc(
      'list_general_request_applicants',
      params: {'p_request_id': requestId},
    );
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true || map['items'] is! List) return const [];
    return (map['items'] as List)
        .whereType<Map>()
        .map(
          (item) =>
              GeneralRequestApplicant.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<AppUser?> fetchGeneralApplicationCounterpartProfile(
    String applicationId,
  ) async {
    final rows = await _supabase.rpc(
      'get_general_application_counterpart_profile',
      params: {'p_application_id': applicationId},
    );
    if (rows is! List || rows.isEmpty) return null;
    return AppUser.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<List<GeneralRequestApplicationSummary>>
  fetchMyGeneralRequestApplications(String userId) async {
    try {
      final raw = await _supabase.rpc(
        'list_my_general_request_applications',
        params: {'p_limit': 20},
      );
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final items = map['items'];
        if (map['ok'] == true && items is List) {
          return items
              .whereType<Map>()
              .map(
                (row) => GeneralRequestApplicationSummary.fromMap(
                  Map<String, dynamic>.from(row),
                ),
              )
              .where((item) => item.request.isGeneralMatching)
              .toList(growable: false);
        }
      }
    } catch (_) {
      // Migration이 아직 적용되지 않은 환경에서는 기존 REST 조회로 폴백한다.
    }

    final rows = await _supabase
        .from('request_applications')
        .select(
          'id, request_id, status, initial_message, created_at, proposed_reward, proposed_by, proposed_at, requester_accepted_at, worker_accepted_at, requests(*)',
        )
        .eq('worker_id', userId)
        .neq('status', 'withdrawn')
        .order('created_at', ascending: false)
        .limit(20);

    return rows
        .whereType<Map>()
        .map(
          (row) => GeneralRequestApplicationSummary.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.request.isGeneralMatching)
        .toList(growable: false);
  }

  /// 요청자/작업자 취소. 서버에서 30초 자유취소·로그·약한 반복 패널티를 처리한다.
  Future<Map<String, dynamic>> cancelRequest(
    String requestId, {
    String? reason,
  }) async {
    final raw = await _supabase.rpc(
      'cancel_matched_request',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
    await flushPushDelivery();
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  /// 한 요청에 대해 Realtime 변경 이벤트 스트림.
  /// `requests` 의 `current_stage`, `status`, `next_advance_at` 등이 바뀔 때마다 새 행을 흘려보낸다.
  Stream<MatchRequest?> watchRequest(String requestId) {
    final controller = _supabase
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId);
    return controller.map((rows) {
      if (rows.isEmpty) return null;
      return MatchRequest.fromMap(rows.first);
    });
  }

  Stream<List<RequestTaskProof>> watchTaskProofs(String requestId) {
    return _supabase
        .from('request_task_proofs')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .asyncMap((rows) async {
          final proofs = <RequestTaskProof>[];
          for (final row in rows) {
            final proof = RequestTaskProof.fromMap(row);
            final imageUrl = await _taskProofDisplayUrl(proof.imageUrl);
            proofs.add(proof.copyWithImageUrl(imageUrl));
          }
          return proofs;
        });
  }

  Future<String> _taskProofDisplayUrl(String raw) async {
    if (raw.startsWith('http')) return raw;
    try {
      return await _supabase.storage
          .from(TtmStorageConstants.taskProofsBucket)
          .createSignedUrl(raw, 3600);
    } catch (_) {
      return raw;
    }
  }

  Future<Map<String, dynamic>> submitTaskProof({
    required String requestId,
    required String proofType,
    required String imageUrl,
  }) async {
    final raw = await _supabase.rpc(
      'submit_private_task_proof',
      params: {
        'p_request_id': requestId,
        'p_proof_type': proofType,
        'p_storage_path': imageUrl,
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> reviewTaskProof({
    required String proofId,
    required bool approved,
    String? reason,
  }) async {
    final raw = await _supabase.rpc(
      'review_task_proof',
      params: {
        'p_proof_id': proofId,
        'p_approved': approved,
        'p_reason': reason,
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  /// 활동 ON 없이 주변 open 요청을 필터로 탐색한다.
  Future<List<WorkerNotification>> browseOpenRequests({
    required String workerId,
    required double latitude,
    required double longitude,
    int? maxDistanceM,
    List<String>? tags,
    num? minReward,
    num? maxReward,
    int? minTaskMinutes,
    int? maxTaskMinutes,
    int limit = 50,
    String matchingMode = 'quick',
  }) async {
    final raw = await _supabase.rpc(
      'browse_open_requests',
      params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_max_distance_m': maxDistanceM,
        'p_tags': tags?.isNotEmpty == true ? tags : null,
        'p_min_reward': minReward,
        'p_max_reward': maxReward,
        'p_min_task_minutes': minTaskMinutes,
        'p_max_task_minutes': maxTaskMinutes,
        'p_limit': limit,
        'p_matching_mode': matchingMode,
      },
    );
    if (raw is! Map) return const [];

    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) return const [];

    final items = map['items'];
    if (items is! List) return const [];

    final list = <WorkerNotification>[];
    for (final item in items) {
      if (item is! Map) continue;
      list.add(
        WorkerNotification.fromBrowseMap(
          Map<String, dynamic>.from(item),
          workerId: workerId,
        ),
      );
    }
    list.sort((a, b) {
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      return da.compareTo(db);
    });
    return list;
  }

  Future<List<WorkerNotification>> fetchRecommendedGeneralRequests({
    required String workerId,
    required MatchRequest current,
    required List<MatchRequest> affinityRequests,
    int limit = 5,
  }) async {
    final latitude = current.requestLatitude ?? 0;
    final longitude = current.requestLongitude ?? 0;
    final candidates = await browseOpenRequests(
      workerId: workerId,
      latitude: latitude,
      longitude: longitude,
      maxDistanceM: 50000,
      limit: 40,
      matchingMode: 'general',
    );
    final currentTokens = _recommendationTokens(current);
    final affinityTaskTypes = <String, int>{};
    final affinityTags = <String, int>{};
    for (final request in affinityRequests) {
      affinityTaskTypes.update(
        request.taskType,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
      for (final tag in request.tags.map(_normalizeRecommendationText)) {
        if (tag.isEmpty) continue;
        affinityTags.update(tag, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    final scored = <({WorkerNotification item, int score})>[];
    for (final item in candidates) {
      final request = item.request;
      if (request == null) continue;
      if (request.id == current.id) continue;
      if (!request.isGeneralMatching || !request.isOpen) continue;

      var score = 0;
      if (request.taskType == current.taskType) score += 36;
      final sharedTags = request.tags
          .map(_normalizeRecommendationText)
          .where(
            (tag) =>
                tag.isNotEmpty &&
                current.tags.map(_normalizeRecommendationText).contains(tag),
          )
          .length;
      score += sharedTags * 18;

      final candidateTokens = _recommendationTokens(request);
      score += candidateTokens.intersection(currentTokens).length * 6;

      score += (affinityTaskTypes[request.taskType] ?? 0).clamp(0, 4) * 10;
      for (final tag in request.tags.map(_normalizeRecommendationText)) {
        score += (affinityTags[tag] ?? 0).clamp(0, 3) * 5;
      }

      final distanceKm = item.distanceKm;
      if (distanceKm != null) {
        if (distanceKm <= 1) {
          score += 10;
        } else if (distanceKm <= 3) {
          score += 6;
        } else if (distanceKm <= 8) {
          score += 3;
        }
      }

      final ageHours = DateTime.now().difference(request.createdAt).inHours;
      if (ageHours <= 24) score += 8;
      if (ageHours <= 6) score += 4;

      scored.add((item: item, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final da = a.item.distanceKm ?? double.infinity;
      final db = b.item.distanceKm ?? double.infinity;
      final byDistance = da.compareTo(db);
      if (byDistance != 0) return byDistance;
      return b.item.createdAt.compareTo(a.item.createdAt);
    });

    return scored
        .take(limit)
        .map((entry) => entry.item)
        .toList(growable: false);
  }

  Set<String> _recommendationTokens(MatchRequest request) {
    final raw = <String>[
      request.displayTitle,
      request.description,
      ...request.tags,
    ].join(' ');
    return raw
        .split(RegExp(r'[^0-9A-Za-z가-힣]+'))
        .map(_normalizeRecommendationText)
        .where((token) => token.length >= 2)
        .take(80)
        .toSet();
  }

  String _normalizeRecommendationText(String value) {
    return value
        .replaceAll('#', '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim()
        .toLowerCase();
  }

  Future<List<MatchRequest>> fetchMyOpenGeneralRequests(String userId) async {
    final rows = await _supabase
        .from('requests')
        .select()
        .eq('requester_id', userId)
        .eq('matching_mode', 'general')
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(50);
    final items = <MatchRequest>[];
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      try {
        final detail = await fetchGeneralRequestDetail(map['id'].toString());
        final firstImage = detail.images.isEmpty
            ? null
            : detail.images.first.imageUrl;
        map['thumbnail_url'] = firstImage;
        map['comment_count'] = detail.commentCount;
        map['application_count'] = detail.applicationCount;
      } catch (_) {
        // 요약 정보가 실패해도 게시글 자체는 보여준다.
      }
      items.add(MatchRequest.fromMap(map));
    }
    return items;
  }

  /// 진행 중인 open 요청에 대해 본인 알림 행을 DB 에 맞춰 넣는다.
  /// (요청 생성 후에 활동 ON 한 경우·Realtime 미적용 시 보강)
  Future<Map<String, dynamic>> syncMyWorkerNotifications() async {
    final raw = await _supabase.rpc('sync_my_worker_notifications');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  /// pending 알림 + 열린 요청 본문을 한 번에 읽는다.
  Future<List<WorkerNotification>> fetchMyPendingNotifications(
    String workerId,
  ) async {
    final raw = await _supabase.rpc('get_my_pending_notifications');
    if (raw is! Map) return const [];

    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) return const [];
    final items = map['items'];
    if (items is! List) return const [];

    final open = items
        .map((row) {
          return WorkerNotification.fromMap(
            Map<String, dynamic>.from(row as Map),
          );
        })
        .where((n) {
          final r = n.request;
          return r != null && r.isOpen;
        });

    // 요청당 최신 단계 알림만 표시 (확장마다 stage가 바뀌며 쌓이던 중복 방지)
    final byRequest = <String, WorkerNotification>{};
    for (final n in open) {
      final prev = byRequest[n.requestId];
      if (prev == null || n.stage > prev.stage) {
        byRequest[n.requestId] = n;
      }
    }
    return byRequest.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 첫 로드는 REST 로, 이후 Realtime 변경 시 다시 읽는다.
  Stream<List<WorkerNotification>> watchMyPendingNotifications(
    String workerId,
  ) async* {
    Future<List<WorkerNotification>> load() =>
        fetchMyPendingNotifications(workerId);

    yield await load();
    try {
      await syncMyWorkerNotifications();
      yield await load();
      await flushPushDelivery();
      yield await load();
    } catch (_) {
      // 마이그레이션 미적용 시 RPC 없음 — REST 결과만 사용
    }

    await for (final _
        in _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('worker_id', workerId)) {
      yield await load();
    }
  }

  /// 작업자가 자신을 online/offline 으로 토글. 위치(좌표) 가 필요한 경우만 채운다.
  Future<void> upsertMyPresence({
    required String workerId,
    required String status,
    double? latitude,
    double? longitude,
    List<String>? preferredTags,
    double? maxDistanceKm,
    bool? shareLocation,
    DateTime? onlineUntil,
    bool clearOnlineUntil = false,
  }) async {
    // PostgREST geography 는 GeoJSON 객체가 아니라 WKT 문자열이 안정적이다.
    final String? geo = (latitude != null && longitude != null)
        ? 'POINT($longitude $latitude)'
        : null;

    final payload = <String, dynamic>{
      'worker_id': workerId,
      'status': status,
      'geo': ?geo,
      'preferred_tags': ?preferredTags,
      'max_distance_km': ?maxDistanceKm,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (onlineUntil != null)
        'online_until': onlineUntil.toUtc().toIso8601String(),
      if (clearOnlineUntil) 'online_until': null,
    };
    if (shareLocation != null) {
      payload['share_location'] = shareLocation;
    } else if (geo != null) {
      payload['share_location'] = status == 'online';
    }

    await _supabase
        .from('worker_presence')
        .upsert(payload, onConflict: 'worker_id');
  }

  /// 매칭 진행 중 작업자 실시간 위치 → requests.worker_live_geo + worker_presence.
  Future<void> publishWorkerMatchLocation({
    required String requestId,
    required double latitude,
    required double longitude,
  }) async {
    await _supabase.rpc(
      'update_worker_match_location',
      params: {
        'p_request_id': requestId,
        'p_lng': longitude,
        'p_lat': latitude,
      },
    );
  }

  /// 작업자 본인의 진행 중(matched) 요청 id. 없으면 null.
  Future<String?> fetchMyActiveMatchedRequestId(String workerId) async {
    final row = await _supabase
        .from('requests')
        .select('id')
        .eq('worker_id', workerId)
        .eq('status', 'matched')
        .order('matched_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Stream<String?> watchMyActiveMatchedRequestId(String workerId) {
    return _supabase
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('worker_id', workerId)
        .map((rows) {
          for (final row in rows) {
            if (row['status'] == 'matched') {
              return row['id'] as String;
            }
          }
          return null;
        });
  }

  /// 요청자·작업자 본인의 진행 중(matched) 심부름 목록 Realtime.
  Stream<List<MatchRequest>> watchMyActiveMatchedRequests(String userId) {
    return _supabase.from('requests').stream(primaryKey: ['id']).map((rows) {
      return rows
          .where((row) {
            if (row['status'] != 'matched') return false;
            return row['requester_id'] == userId || row['worker_id'] == userId;
          })
          .map((row) => MatchRequest.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    });
  }

  Stream<List<MatchRequest>> watchMyCompletedRequests(String userId) {
    return _supabase.from('requests').stream(primaryKey: ['id']).map((rows) {
      final items = rows
          .where((row) {
            if (row['status'] != 'completed') return false;
            return row['requester_id'] == userId || row['worker_id'] == userId;
          })
          .map((row) => MatchRequest.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      items.sort((a, b) {
        final ad = a.completedAt ?? a.createdAt;
        final bd = b.completedAt ?? b.createdAt;
        return bd.compareTo(ad);
      });
      return items;
    });
  }

  Future<List<MatchRequest>> fetchMyCompletedWorkRequests(String userId) async {
    final rows = await _supabase
        .from('requests')
        .select()
        .eq('worker_id', userId)
        .eq('status', 'completed')
        .order('completed_at', ascending: false)
        .limit(50);
    return rows
        .map((row) => MatchRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<MatchRequest>> fetchMyCompletedRequestedRequests(
    String userId,
  ) async {
    final rows = await _supabase
        .from('requests')
        .select()
        .eq('requester_id', userId)
        .eq('status', 'completed')
        .order('completed_at', ascending: false)
        .limit(50);
    return rows
        .map((row) => MatchRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  /// 요청자: 작업자에게 실시간 위치 공개 on/off.
  Future<Map<String, dynamic>> setRequesterShareLocation({
    required String requestId,
    required bool share,
  }) async {
    final raw = await _supabase.rpc(
      'set_requester_share_location',
      params: {'p_request_id': requestId, 'p_share': share},
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'ok': false, 'reason': 'unexpected_response'};
  }

  /// 요청자: 공유 ON 상태에서 GPS 갱신.
  Future<Map<String, dynamic>> updateRequesterLiveLocation({
    required String requestId,
    required double latitude,
    required double longitude,
  }) async {
    final raw = await _supabase.rpc(
      'update_requester_live_location',
      params: {
        'p_request_id': requestId,
        'p_lng': longitude,
        'p_lat': latitude,
      },
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'ok': false, 'reason': 'unexpected_response'};
  }
}
