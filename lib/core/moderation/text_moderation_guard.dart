import 'package:supabase_flutter/supabase_flutter.dart';

import 'text_moderation_lexicon.dart';

class TextModerationGuard {
  const TextModerationGuard(this._supabase);

  final SupabaseClient _supabase;

  Future<void> ensureAllowed({
    required String contextType,
    required String text,
    String? targetType,
    String? targetId,
    String? requestId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final localReason = localTextModerationReason(trimmed);

    try {
      final res = await _supabase.functions.invoke(
        'text-moderation',
        body: {
          'context_type': contextType,
          'text': trimmed,
          'target_type': ?targetType,
          'target_id': ?targetId,
          'request_id': ?requestId,
        },
      );
      final data = res.data;
      if (data is! Map) {
        throw const PostgrestException(
          message: '유해 표현 검사 응답을 확인하지 못했어요.',
          code: 'moderation_unavailable',
        );
      }
      final map = Map<String, dynamic>.from(data);
      if (map['allowed'] == false || map['ok'] == false) {
        throw PostgrestException(
          message: map['message']?.toString().trim().isNotEmpty == true
              ? map['message'].toString()
              : _messageForContext(contextType),
          code: map['code']?.toString() ?? 'moderation_blocked',
          details: map,
        );
      }
      if (localReason != null) {
        throw PostgrestException(
          message: _messageForContext(contextType),
          code: 'moderation_blocked',
          details: {'reason': localReason, 'context_type': contextType},
        );
      }
    } on PostgrestException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map) {
        final map = Map<String, dynamic>.from(details);
        final code = map['code']?.toString() ?? map['reason']?.toString();
        if (code == 'moderation_blocked' || map['allowed'] == false) {
          throw PostgrestException(
            message: map['message']?.toString().trim().isNotEmpty == true
                ? map['message'].toString()
                : _messageForContext(contextType),
            code: 'moderation_blocked',
            details: map,
          );
        }
      }

      // Keep local protection if the server function is not available yet.
      if (e.status == 404) {
        if (localReason != null) {
          throw PostgrestException(
            message: _messageForContext(contextType),
            code: 'moderation_blocked',
            details: {'reason': localReason, 'context_type': contextType},
          );
        }
        return;
      }
      throw PostgrestException(
        message: '유해 표현 검사에 실패했어요. 잠시 후 다시 시도해 주세요.',
        code: 'moderation_unavailable',
        details: details,
      );
    } catch (e) {
      throw PostgrestException(
        message: '유해 표현 검사에 실패했어요. 잠시 후 다시 시도해 주세요.',
        code: 'moderation_unavailable',
        details: e.toString(),
      );
    }
  }

  Future<void> ensureAllowedFields({
    required String contextType,
    required Map<String, String?> fields,
    String? targetType,
    String? targetId,
    String? requestId,
  }) {
    final text = fields.entries
        .map((entry) {
          final value = entry.value?.trim();
          if (value == null || value.isEmpty) return null;
          return '${entry.key}: $value';
        })
        .whereType<String>()
        .join('\n');

    return ensureAllowed(
      contextType: contextType,
      text: text,
      targetType: targetType,
      targetId: targetId,
      requestId: requestId,
    );
  }

  String _messageForContext(String contextType) {
    if (contextType == 'nickname') {
      return '닉네임으로 사용할 수 없는 표현입니다.';
    }
    if (contextType.contains('post') || contextType.contains('request')) {
      return '게시할 수 없는 표현이 포함되어 요청을 등록하지 않았어요.';
    }
    if (contextType.contains('chat')) {
      return '전송할 수 없는 표현이 포함되어 메시지를 보내지 않았어요.';
    }
    return '등록할 수 없는 표현이 포함되어 처리하지 않았어요.';
  }
}
