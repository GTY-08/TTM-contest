import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/moderation/text_moderation_guard.dart';
import '../../../core/push/push_flush.dart';
import '../../../data/repositories/chat_attachment_repository.dart';
import '../models/chat_message.dart';

export '../models/chat_message.dart';

/// 매칭 후 DM, 읽음, 첨부, 후기.
class ChatRepository {
  ChatRepository(this._supabase, {ChatAttachmentRepository? attachments})
    : _attachments = attachments ?? ChatAttachmentRepository(_supabase),
      _moderation = TextModerationGuard(_supabase);

  final SupabaseClient _supabase;
  final ChatAttachmentRepository _attachments;
  final TextModerationGuard _moderation;

  Stream<({List<ChatMessage> messages, ChatReadState reads})>
  watchMessagesWithReads(String requestId) {
    Future<({List<ChatMessage> messages, ChatReadState reads})> load() async {
      final uid = _supabase.auth.currentUser?.id;
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('request_id', requestId)
          .order('created_at', ascending: true);
      final messages = rows
          .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      final reads = await _fetchReadState(requestId, uid);
      return (messages: messages, reads: reads);
    }

    final out =
        StreamController<({List<ChatMessage> messages, ChatReadState reads})>();
    StreamSubscription<dynamic>? msgSub;
    StreamSubscription<dynamic>? readSub;
    var emitInFlight = false;
    var emitAgain = false;

    Future<void> emit() async {
      if (out.isClosed) return;
      if (emitInFlight) {
        emitAgain = true;
        return;
      }
      emitInFlight = true;
      try {
        do {
          emitAgain = false;
          out.add(await load());
        } while (emitAgain && !out.isClosed);
      } catch (e, st) {
        out.addError(e, st);
      } finally {
        emitInFlight = false;
      }
    }

    out.onListen = () {
      unawaited(emit());
      msgSub = _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('request_id', requestId)
          .listen((_) => unawaited(emit()));
      readSub = _supabase
          .from('request_chat_reads')
          .stream(primaryKey: ['request_id', 'user_id'])
          .eq('request_id', requestId)
          .listen((_) => unawaited(emit()));
    };

    out.onCancel = () async {
      await msgSub?.cancel();
      await readSub?.cancel();
    };

    return out.stream;
  }

  Future<ChatReadState> _fetchReadState(String requestId, String? uid) async {
    if (uid == null) return const ChatReadState();

    final req = await _supabase
        .from('requests')
        .select('requester_id, worker_id')
        .eq('id', requestId)
        .maybeSingle();
    if (req == null) return const ChatReadState();

    final requesterId = req['requester_id'] as String;
    final workerId = req['worker_id'] as String?;
    final counterpartId = uid == requesterId
        ? workerId
        : (uid == workerId ? requesterId : null);
    if (counterpartId == null) return const ChatReadState();

    final rows = await _supabase
        .from('request_chat_reads')
        .select('user_id, last_read_at')
        .eq('request_id', requestId)
        .inFilter('user_id', [uid, counterpartId]);

    DateTime? myRead;
    DateTime? theirRead;
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      final at = DateTime.tryParse(map['last_read_at']?.toString() ?? '');
      if (map['user_id'] == uid) {
        myRead = at;
      } else if (map['user_id'] == counterpartId) {
        theirRead = at;
      }
    }

    return ChatReadState(
      myLastReadAt: myRead,
      counterpartLastReadAt: theirRead,
    );
  }

  Future<void> markAsRead(String requestId) async {
    await _supabase.rpc(
      'mark_request_chat_read',
      params: {'p_request_id': requestId},
    );
  }

  Future<void> sendMessage({
    required String requestId,
    required String content,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    await _moderation.ensureAllowed(
      contextType: 'match_chat',
      text: trimmed,
      targetType: 'request',
      targetId: requestId,
      requestId: requestId,
    );

    await _supabase.from('messages').insert({
      'request_id': requestId,
      'sender_id': uid,
      'content': trimmed,
      'message_type': 'text',
    });
    await flushPushOutbox(_supabase);
  }

  Future<void> sendImageMessage({
    required String requestId,
    required File file,
    String? caption,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final url = await _attachments.uploadChatImage(
      requestId: requestId,
      file: file,
    );
    final cleanCaption = caption?.trim() ?? '';
    if (cleanCaption.isNotEmpty) {
      await _moderation.ensureAllowed(
        contextType: 'match_chat',
        text: cleanCaption,
        targetType: 'request',
        targetId: requestId,
        requestId: requestId,
      );
    }

    await _supabase.from('messages').insert({
      'request_id': requestId,
      'sender_id': uid,
      'content': cleanCaption,
      'message_type': 'image',
      'attachment_url': url,
    });
    await flushPushOutbox(_supabase);
  }

  Future<void> sendImageMessages({
    required String requestId,
    required List<File> files,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');
    if (files.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final file in files) {
      final url = await _attachments.uploadChatImage(
        requestId: requestId,
        file: file,
      );
      rows.add({
        'request_id': requestId,
        'sender_id': uid,
        'content': '',
        'message_type': 'image',
        'attachment_url': url,
      });
    }

    await _supabase.from('messages').insert(rows);
    await flushPushOutbox(_supabase);
  }

  Future<void> deleteMyMessage(String messageId) async {
    try {
      await _supabase.rpc(
        'mark_message_deleted',
        params: {'p_message_id': messageId},
      );
    } on PostgrestException catch (e) {
      if (!_isMissingDeleteRpc(e)) rethrow;
      await _supabase
          .from('messages')
          .update({
            'content': '삭제된 메세지입니다.',
            'message_type': 'text',
            'attachment_url': null,
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', _supabase.auth.currentUser?.id ?? '');
    }
  }

  bool _isMissingDeleteRpc(PostgrestException e) {
    final text = '${e.code} ${e.message} ${e.details ?? ''}'.toLowerCase();
    return text.contains('pgrst202') ||
        text.contains('could not find the function') ||
        text.contains('function public.mark_message_deleted') ||
        text.contains('mark_message_deleted');
  }

  RealtimeChannel watchTyping({
    required String requestId,
    required void Function(String userId, bool isTyping) onTyping,
  }) {
    final channel = _supabase.channel('chat_typing:$requestId');
    channel
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id']?.toString();
            if (userId == null || userId.isEmpty) return;
            onTyping(userId, payload['is_typing'] == true);
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> sendTyping({
    required RealtimeChannel channel,
    required bool isTyping,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': uid,
        'is_typing': isTyping,
        'sent_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> removeChannel(RealtimeChannel channel) {
    return _supabase.removeChannel(channel);
  }

  Future<bool> hasMyReviewForRequest(String requestId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return true;
    final row = await _supabase
        .from('reviews')
        .select('id')
        .eq('request_id', requestId)
        .eq('reviewer_id', uid)
        .maybeSingle();
    return row != null;
  }

  Future<void> submitReview({
    required String requestId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');
    final cleanComment = comment?.trim();
    if (cleanComment?.isNotEmpty == true) {
      await _moderation.ensureAllowed(
        contextType: 'review_comment',
        text: cleanComment!,
        targetType: 'request',
        targetId: requestId,
        requestId: requestId,
      );
    }

    await _supabase.from('reviews').insert({
      'request_id': requestId,
      'reviewer_id': uid,
      'reviewee_id': revieweeId,
      'rating': rating,
      if (cleanComment != null && cleanComment.isNotEmpty)
        'comment': cleanComment,
    });
  }
}
