import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/moderation/text_moderation_guard.dart';
import '../../data/providers/auth_providers.dart';

const ttmUserReportCategories = [
  '잠수/응답 없음',
  '작업 미수행',
  '작업 품질 문제',
  '부당한 완료 요청',
  '부당한 취소/환불 요구',
  '욕설/협박/불쾌한 대화',
  '사기/금전 요구',
  '기타',
];

const ttmMessageReportCategories = [
  '욕설/비방',
  '협박/위협',
  '성희롱/불쾌한 표현',
  '사기/외부 결제 유도',
  '개인정보 요구',
  '스팸/도배',
  '기타',
];

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(supabaseClientProvider));
});

final adminUserReportsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(reportRepositoryProvider).fetchUserReports();
});

final adminMessageReportsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(reportRepositoryProvider).fetchMessageReports();
});

class ReportRepository {
  ReportRepository(this._supabase)
    : _moderation = TextModerationGuard(_supabase);

  final SupabaseClient _supabase;
  final TextModerationGuard _moderation;

  Future<void> submitUserReport({
    required String reportedUserId,
    required String category,
    String? requestId,
    String? description,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');
    await _moderateDescription(
      description,
      targetType: 'user_report',
      targetId: reportedUserId,
      requestId: requestId,
    );

    await _supabase.from('user_reports').insert({
      'reporter_id': uid,
      'reported_user_id': reportedUserId,
      'request_id': requestId,
      'category': category,
      'description': _cleanDescription(description),
    });
  }

  Future<void> submitMessageReport({
    required String reportedUserId,
    required String requestId,
    required String messageId,
    required String category,
    required String messageSnapshot,
    String? description,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');
    await _moderateDescription(
      description,
      targetType: 'message_report',
      targetId: messageId,
      requestId: requestId,
    );

    await _supabase.from('message_reports').insert({
      'reporter_id': uid,
      'reported_user_id': reportedUserId,
      'request_id': requestId,
      'message_id': messageId,
      'category': category,
      'description': _cleanDescription(description),
      'message_snapshot': messageSnapshot.trim().isEmpty
          ? '(내용 없음)'
          : messageSnapshot.trim(),
    });
  }

  Future<void> submitGeneralApplicationMessageReport({
    required String reportedUserId,
    required String requestId,
    required String applicationId,
    required String messageId,
    required String category,
    required String messageSnapshot,
    String? description,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');
    await _moderateDescription(
      description,
      targetType: 'general_application_message_report',
      targetId: messageId,
      requestId: requestId,
    );

    await _supabase.from('request_application_message_reports').insert({
      'reporter_id': uid,
      'reported_user_id': reportedUserId,
      'request_id': requestId,
      'application_id': applicationId,
      'message_id': messageId,
      'category': category,
      'description': _cleanDescription(description),
      'message_snapshot': messageSnapshot.trim().isEmpty
          ? '(내용 없음)'
          : messageSnapshot.trim(),
    });
  }

  Future<void> submitRaidMessageReport({
    required String raidId,
    required String messageId,
    required String category,
    String? description,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');
    await _moderateDescription(
      description,
      targetType: 'raid_message_report',
      targetId: messageId,
      requestId: raidId,
    );

    final raw = await _supabase.rpc(
      'submit_raid_message_report',
      params: {
        'p_message_id': messageId,
        'p_category': category,
        'p_description': _cleanDescription(description),
      },
    );
    if (raw is! Map || raw['ok'] != true) {
      final reason = raw is Map ? raw['reason']?.toString() : null;
      throw StateError(reason ?? 'report_submit_failed');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserReports() async {
    final rows = await _supabase
        .from('user_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMessageReports() async {
    final rows = await _supabase
        .from('message_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> updateUserReportStatus({
    required String reportId,
    required String status,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    await _supabase
        .from('user_reports')
        .update({
          'status': status,
          'reviewed_by': uid,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reportId);
  }

  Future<void> updateMessageReportStatus({
    required String reportId,
    required String status,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    await _supabase
        .from('message_reports')
        .update({
          'status': status,
          'reviewed_by': uid,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reportId);
  }

  String? _cleanDescription(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _moderateDescription(
    String? value, {
    required String targetType,
    String? targetId,
    String? requestId,
  }) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    await _moderation.ensureAllowed(
      contextType: 'report_description',
      text: trimmed,
      targetType: targetType,
      targetId: targetId,
      requestId: requestId,
    );
  }
}
