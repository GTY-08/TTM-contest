import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time_ko.dart';
import '../../profile/widgets/profile_photo_change.dart';
import '../models/chat_message.dart';

/// DM 말풍선 — 아바타·시각·읽음(1)·이미지.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.unreadByCounterpart,
    this.showReadReceipt = false,
    this.showSenderName = false,
    this.showAvatar = true,
    this.onAvatarTap,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final String senderName;
  final String? senderAvatarUrl;
  final bool unreadByCounterpart;
  final bool showReadReceipt;
  final bool showSenderName;
  final bool showAvatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;

  static String formatMessageTime(DateTime createdAt) {
    final now = DateTime.now();
    final sameDay =
        createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
    if (sameDay) {
      final h = createdAt.hour.toString().padLeft(2, '0');
      final m = createdAt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (now.difference(createdAt).inDays < 7) {
      return formatRelativeTimeKo(createdAt, now: now);
    }
    return '${createdAt.month}/${createdAt.day} '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.68;
    final bg = isMine
        ? (isDark ? TtmColors.primaryDark : TtmColors.primary)
        : colors.surface;
    final fg = message.isDeleted
        ? colors.onSurfaceVariant.withValues(alpha: 0.72)
        : (isMine ? Colors.white : colors.onSurface);
    final border = isMine
        ? null
        : Border.all(color: colors.outlineVariant.withValues(alpha: 0.45));
    final timeLabel = formatMessageTime(message.createdAt);

    final bubbleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isDeleted)
          Text(
            '삭제된 메시지입니다.',
            style: TtmTypography.body.copyWith(
              fontSize: 15,
              color: fg,
              fontStyle: FontStyle.italic,
            ),
          )
        else if (message.isImage && message.attachmentUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(TtmRadius.sm),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth - 24),
              child: Image.network(
                message.attachmentUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: maxBubbleWidth * 0.55,
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: isMine ? Colors.white70 : colors.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => Text(
                  '이미지를 불러오지 못했어요',
                  style: TtmTypography.body.copyWith(fontSize: 13, color: fg),
                ),
              ),
            ),
          ),
          if (message.content.trim().isNotEmpty) ...[
            const SizedBox(height: TtmSpacing.sm),
            Text(
              message.content,
              style: TtmTypography.body.copyWith(fontSize: 15, color: fg),
            ),
          ],
        ] else
          Text(
            message.content,
            style: TtmTypography.body.copyWith(fontSize: 15, color: fg),
          ),
      ],
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: TtmSpacing.md,
        vertical: TtmSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(TtmRadius.md),
          topRight: const Radius.circular(TtmRadius.md),
          bottomLeft: Radius.circular(isMine ? TtmRadius.md : 4),
          bottomRight: Radius.circular(isMine ? 4 : TtmRadius.md),
        ),
        border: border,
        boxShadow: isMine
            ? [
                BoxShadow(
                  color: bg.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: bubbleContent,
    );

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMine && unreadByCounterpart) ...[
          Text(
            '1',
            style: TtmTypography.label.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 4),
        ] else if (isMine && showReadReceipt) ...[
          Text(
            '읽음',
            style: TtmTypography.label.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          timeLabel,
          style: TtmTypography.label.copyWith(
            fontSize: 10,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );

    Widget avatar = TtmProfileAvatar(
      imageUrl: senderAvatarUrl,
      size: 32,
      borderWidth: 1,
    );
    if (onAvatarTap != null) {
      avatar = GestureDetector(onTap: onAvatarTap, child: avatar);
    }

    final avatarSlot = SizedBox(
      width: 32,
      height: 32,
      child: showAvatar ? avatar : null,
    );

    final messageColumn = Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSenderName && !isMine) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              senderName,
              style: TtmTypography.label.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        bubble,
        const SizedBox(height: 4),
        meta,
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: TtmSpacing.sm),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isMine) ...[avatarSlot, const SizedBox(width: TtmSpacing.sm)],
            Flexible(fit: FlexFit.loose, child: messageColumn),
            if (isMine) ...[const SizedBox(width: TtmSpacing.sm), avatarSlot],
          ],
        ),
      ),
    );
  }
}
