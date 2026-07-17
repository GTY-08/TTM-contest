import 'package:flutter/foundation.dart';

/// `public.messages` 한 행.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.messageType,
    this.attachmentUrl,
    this.deletedAt,
  });

  final String id;
  final String requestId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String messageType;
  final String? attachmentUrl;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isImage => messageType == 'image';
  bool get isText => messageType == 'text';

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      requestId: map['request_id'] as String,
      senderId: map['sender_id'] as String,
      content: (map['content'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      messageType: (map['message_type'] as String?) ?? 'text',
      attachmentUrl: map['attachment_url'] as String?,
      deletedAt: DateTime.tryParse(map['deleted_at']?.toString() ?? ''),
    );
  }
}

/// 참가자별 마지막 읽은 시각.
@immutable
class ChatReadState {
  const ChatReadState({this.myLastReadAt, this.counterpartLastReadAt});

  final DateTime? myLastReadAt;
  final DateTime? counterpartLastReadAt;

  bool isReadByCounterpart(ChatMessage message) {
    final readAt = counterpartLastReadAt;
    if (readAt == null) return false;
    return !message.createdAt.isAfter(readAt);
  }

  /// 상대가 보낸 메시지 중 아직 읽지 않은 개수.
  int unreadFromCounterpart(
    List<ChatMessage> messages, {
    required String myUserId,
  }) {
    return messages.where((m) {
      if (m.senderId == myUserId) return false;
      final readAt = myLastReadAt;
      if (readAt == null) return true;
      return m.createdAt.isAfter(readAt);
    }).length;
  }
}
