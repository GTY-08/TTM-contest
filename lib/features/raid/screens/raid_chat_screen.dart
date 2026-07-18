import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/display_nickname.dart';
import '../../../core/utils/restriction_error_message.dart';
import '../../../core/utils/ttm_snackbar.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/user_restriction.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/user_restriction_notice.dart';
import '../../chat/models/chat_message.dart';
import '../../chat/widgets/chat_message_bubble.dart';
import '../../chat/widgets/counterpart_profile_sheet.dart';
import '../../profile/widgets/profile_photo_change.dart';
import '../../reports/report_dialog.dart';
import '../../reports/report_repository.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';

class RaidChatScreen extends ConsumerStatefulWidget {
  const RaidChatScreen({super.key, required this.raidId});

  final String raidId;

  @override
  ConsumerState<RaidChatScreen> createState() => _RaidChatScreenState();
}

enum _RaidImagePickMode { gallery, camera }

class _RaidChatScreenState extends ConsumerState<RaidChatScreen> {
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  final _typingExpiryTimers = <String, Timer>{};
  final _typingUserIds = <String>{};

  Timer? _readMarkTimer;
  Timer? _typingStopTimer;
  RealtimeChannel? _typingChannel;
  bool _sending = false;
  bool _pickingImage = false;
  bool _sentTyping = false;
  bool _initialScrollDone = false;
  bool _showJumpToBottom = false;
  bool _forceScrollToEnd = false;
  int _lastMessageCount = 0;
  String? _lastMessageId;
  ChatMessage? _pendingMessage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScrollChanged);
    _composer.addListener(_handleComposerChanged);
    _typingChannel = ref
        .read(raidRepositoryProvider)
        .watchRaidTyping(raidId: widget.raidId, onTyping: _handleTyping);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleMarkRead());
  }

  @override
  void dispose() {
    _readMarkTimer?.cancel();
    _typingStopTimer?.cancel();
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    final channel = _typingChannel;
    if (channel != null) {
      unawaited(_sendTyping(false));
      unawaited(
        ref.read(raidRepositoryProvider).removeRealtimeChannel(channel),
      );
    }
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _handleTyping(String userId, bool isTyping) {
    final uid = ref.read(authUserIdProvider);
    if (!mounted || userId == uid) return;
    _typingExpiryTimers[userId]?.cancel();
    setState(() {
      if (isTyping) {
        _typingUserIds.add(userId);
      } else {
        _typingUserIds.remove(userId);
      }
    });
    if (isTyping) {
      _typingExpiryTimers[userId] = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _typingUserIds.remove(userId));
      });
    }
  }

  void _handleComposerChanged() {
    final hasText = _composer.text.trim().isNotEmpty;
    if (hasText && !_sentTyping) {
      _sentTyping = true;
      unawaited(_sendTyping(true));
    }
    _typingStopTimer?.cancel();
    if (hasText) {
      _typingStopTimer = Timer(const Duration(milliseconds: 1200), () {
        _sentTyping = false;
        unawaited(_sendTyping(false));
      });
    } else if (_sentTyping) {
      _sentTyping = false;
      unawaited(_sendTyping(false));
    }
  }

  Future<void> _sendTyping(bool isTyping) async {
    final channel = _typingChannel;
    if (channel == null) return;
    try {
      await ref
          .read(raidRepositoryProvider)
          .sendRaidTyping(channel: channel, isTyping: isTyping);
    } catch (_) {}
  }

  void _handleScrollChanged() {
    if (!_scroll.hasClients) return;
    final away = _distanceFromBottom() > 180;
    if (away == _showJumpToBottom) return;
    setState(() {
      _showJumpToBottom = away;
      if (!away) _pendingMessage = null;
    });
  }

  double _distanceFromBottom() {
    if (!_scroll.hasClients) return 0;
    final position = _scroll.position;
    return (position.maxScrollExtent - position.pixels).clamp(
      0,
      double.infinity,
    );
  }

  void _scheduleMarkRead() {
    _readMarkTimer?.cancel();
    _readMarkTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_markRead());
    });
  }

  Future<void> _markRead() async {
    try {
      await ref.read(raidRepositoryProvider).markChatRead(widget.raidId);
    } catch (_) {}
  }

  void _handleMessagesUpdated(
    ({List<ChatMessage> messages, Map<String, DateTime> reads}) bundle,
    String? uid,
  ) {
    final messages = bundle.messages;
    final latest = messages.isEmpty ? null : messages.last;
    final changed =
        messages.length != _lastMessageCount || latest?.id != _lastMessageId;
    if (changed) {
      final shouldForce = _forceScrollToEnd;
      _forceScrollToEnd = false;
      if (_initialScrollDone &&
          uid != null &&
          latest != null &&
          latest.senderId != uid &&
          _distanceFromBottom() > 180) {
        setState(() {
          _pendingMessage = latest;
          _showJumpToBottom = true;
        });
      }
      _scrollToEnd(force: shouldForce);
    }
    _lastMessageCount = messages.length;
    _lastMessageId = latest?.id;
  }

  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (!_initialScrollDone || force) {
        _initialScrollDone = true;
        _pendingMessage = null;
        _showJumpToBottom = false;
        _scroll.jumpTo(position.maxScrollExtent);
        return;
      }
      if ((position.maxScrollExtent - position.pixels) < 150) {
        _scroll.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      setState(() {
        _pendingMessage = null;
        _showJumpToBottom = false;
      });
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _forceScrollToEnd = true;
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .sendMessage(widget.raidId, text);
      if (result['ok'] != true) {
        throw StateError(result['reason']?.toString() ?? 'message_send_failed');
      }
      if (mounted) {
        _composer.clear();
        await _markRead();
      }
    } on PostgrestException catch (error) {
      _forceScrollToEnd = false;
      final restriction = restrictionErrorMessage(error);
      if (mounted) _show(restriction.isNotEmpty ? restriction : error.message);
    } catch (error) {
      _forceScrollToEnd = false;
      if (mounted) _show('메시지를 보내지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_pickingImage || _sending) return;
    final mode = await showModalBottomSheet<_RaidImagePickMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              subtitle: const Text('여러 장을 한 번에 보낼 수 있어요'),
              onTap: () => Navigator.pop(context, _RaidImagePickMode.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, _RaidImagePickMode.camera),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;

    setState(() => _pickingImage = true);
    _forceScrollToEnd = true;
    try {
      final picker = ImagePicker();
      final List<XFile> picked;
      if (mode == _RaidImagePickMode.gallery) {
        picked = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      } else {
        final image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        picked = image == null ? const [] : [image];
      }
      if (picked.isEmpty || !mounted) {
        _forceScrollToEnd = false;
        return;
      }
      await ref
          .read(raidRepositoryProvider)
          .sendRaidGroupImageMessages(
            raidId: widget.raidId,
            files: picked.map((image) => File(image.path)).toList(),
          );
      if (mounted) await _markRead();
    } on PostgrestException catch (error) {
      _forceScrollToEnd = false;
      final restriction = restrictionErrorMessage(error);
      if (mounted) _show(restriction.isNotEmpty ? restriction : error.message);
    } catch (error) {
      _forceScrollToEnd = false;
      if (mounted) _show('사진을 보내지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠어요? 삭제 후에는 삭제된 메시지로 표시돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(raidRepositoryProvider).deleteRaidMessage(message.id);
    } catch (error) {
      if (mounted) _show('메시지를 삭제하지 못했어요: $error');
    }
  }

  Future<void> _report(ChatMessage message) async {
    final result = await showReportDialog(
      context: context,
      title: '메시지 신고',
      categories: ttmMessageReportCategories,
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(reportRepositoryProvider)
          .submitRaidMessageReport(
            raidId: widget.raidId,
            messageId: message.id,
            category: result.category,
            description: result.description,
          );
      if (mounted) _show('신고가 접수됐어요.');
    } catch (error) {
      if (mounted) _show('신고를 접수하지 못했어요: $error');
    }
  }

  void _openProfile(RaidParticipant participant) {
    final user = AppUser(
      id: participant.userId,
      nickname: participant.nickname ?? '참가자',
      email: null,
      isPremium: participant.isPremium,
      notificationMode: 'push',
      rating: participant.rating ?? 0,
      ratingCount: 0,
      profileImageUrl: participant.profileImageUrl,
      onboardingCompletedAt: null,
      marketingOptIn: false,
      marketingOptInAt: null,
      requesterPenaltyUntil: null,
      workerPenaltyUntil: null,
      isAdmin: false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    unawaited(
      showCounterpartProfileSheet(
        context,
        user: user,
        counterpartIsRequester: false,
        counterpartRoleLabel: participant.isOrganizer ? '레이드 운영자' : '참가자',
      ),
    );
  }

  void _show(String message) => showTtmSnackBar(context, message);

  String _preview(ChatMessage message) {
    if (message.isImage) return '사진';
    return message.content.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUserIdProvider);
    final detailAsync = ref.watch(raidDetailProvider(widget.raidId));
    final messageAsync = ref.watch(raidMessagesProvider(widget.raidId));

    ref.listen(raidMessagesProvider(widget.raidId), (_, next) {
      next.whenData((bundle) {
        _handleMessagesUpdated(bundle, uid);
        if (uid == null) return;
        final readAt = bundle.reads[uid];
        final hasUnread = bundle.messages.any(
          (message) =>
              message.senderId != uid &&
              (readAt == null || message.createdAt.isAfter(readAt)),
        );
        if (hasUnread) _scheduleMarkRead();
      });
    });

    return detailAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('레이드 단체채팅')),
        body: Center(child: Text('단체채팅을 불러오지 못했어요.\n$error')),
      ),
      data: (detail) {
        final participants = detail.participants
            .where((participant) => participant.isApproved)
            .toList(growable: false);
        final participantsById = {
          for (final participant in participants)
            participant.userId: participant,
        };
        final restrictions =
            ref.watch(myActiveRestrictionsProvider).valueOrNull ?? const [];
        final chatBlocked = restrictions.blocksChat;
        final readOnly = {
          'completed',
          'cancelled',
        }.contains(detail.raid.status);
        final canSend = !readOnly && !chatBlocked;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('레이드 단체채팅'),
            scrolledUnderElevation: 0,
          ),
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RaidGroupHeader(
                    raid: detail.raid,
                    participants: participants,
                  ),
                  if (readOnly)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TtmSpacing.lg,
                        TtmSpacing.sm,
                        TtmSpacing.lg,
                        0,
                      ),
                      child: Text(
                        '종료된 레이드예요. 대화는 읽기만 가능해요.',
                        textAlign: TextAlign.center,
                        style: TtmTypography.body.copyWith(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      TtmSpacing.lg,
                      TtmSpacing.sm,
                      TtmSpacing.lg,
                      0,
                    ),
                    child: UserRestrictionNotice(
                      onlyBlockingChat: true,
                      compact: true,
                    ),
                  ),
                  Expanded(
                    child: messageAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) =>
                          Center(child: Text('메시지를 불러오지 못했어요.\n$error')),
                      data: (bundle) {
                        final messages = bundle.messages;
                        if (messages.isEmpty && _typingUserIds.isEmpty) {
                          return Center(
                            child: Text(
                              canSend ? '첫 메시지를 남겨 보세요.' : '저장된 메시지가 없어요.',
                              style: TtmTypography.body.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                            horizontal: TtmSpacing.lg,
                            vertical: TtmSpacing.sm,
                          ),
                          itemCount:
                              messages.length +
                              (_typingUserIds.isEmpty ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (index == messages.length) {
                              final names = _typingUserIds
                                  .map(
                                    (id) => ttmDisplayNickname(
                                      participantsById[id]?.nickname,
                                    ),
                                  )
                                  .join(', ');
                              return _GroupTypingIndicator(names: names);
                            }
                            final message = messages[index];
                            final mine = message.senderId == uid;
                            final sender = participantsById[message.senderId];
                            final previous = index > 0
                                ? messages[index - 1]
                                : null;
                            final showName =
                                !mine &&
                                (previous == null ||
                                    previous.senderId != message.senderId ||
                                    message.createdAt
                                            .difference(previous.createdAt)
                                            .inMinutes >
                                        5);
                            final showAvatar =
                                index == messages.length - 1 ||
                                messages[index + 1].senderId !=
                                    message.senderId ||
                                messages[index + 1].createdAt
                                        .difference(message.createdAt)
                                        .inMinutes >
                                    5;
                            final unreadCount = mine
                                ? participants.where((participant) {
                                    if (participant.userId == uid) return false;
                                    final readAt =
                                        bundle.reads[participant.userId];
                                    return readAt == null ||
                                        readAt.isBefore(message.createdAt);
                                  }).length
                                : 0;

                            return ChatMessageBubble(
                              message: message,
                              isMine: mine,
                              senderName: mine
                                  ? '나'
                                  : ttmDisplayNickname(sender?.nickname),
                              senderAvatarUrl: sender?.profileImageUrl,
                              unreadByCounterpart: unreadCount > 0,
                              unreadCount: unreadCount,
                              showSenderName: showName,
                              showAvatar: showAvatar,
                              onAvatarTap: mine || sender == null
                                  ? null
                                  : () => _openProfile(sender),
                              onLongPress: message.isDeleted
                                  ? null
                                  : (mine
                                        ? () => _confirmDelete(message)
                                        : () => _report(message)),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (!readOnly)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          TtmSpacing.md,
                          TtmSpacing.sm,
                          TtmSpacing.md,
                          TtmSpacing.md,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: '사진 보내기',
                              onPressed: (!canSend || _sending || _pickingImage)
                                  ? null
                                  : _pickAndSendImage,
                              icon: _pickingImage
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.image_outlined),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _composer,
                                minLines: 1,
                                maxLines: 4,
                                enabled: canSend,
                                textInputAction: TextInputAction.newline,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: chatBlocked
                                      ? '채팅 기능 제한 중'
                                      : '메시지 입력',
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: TtmSpacing.md,
                                    vertical: TtmSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: TtmSpacing.sm),
                            IconButton.filled(
                              onPressed: (!canSend || _sending) ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (_showJumpToBottom || _pendingMessage != null)
                Positioned(
                  left: TtmSpacing.lg,
                  right: TtmSpacing.lg,
                  bottom: 86,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Material(
                      elevation: 8,
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _jumpToBottom,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TtmSpacing.md,
                            vertical: 9,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              if (_pendingMessage != null) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _preview(_pendingMessage!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RaidGroupHeader extends StatelessWidget {
  const _RaidGroupHeader({required this.raid, required this.participants});

  final Raid raid;
  final List<RaidParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatars = participants.take(3).toList(growable: false);
    return Material(
      color: colors.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.lg,
          TtmSpacing.md,
          TtmSpacing.lg,
          TtmSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44 + ((avatars.length - 1).clamp(0, 2) * 22),
              height: 44,
              child: Stack(
                children: [
                  for (var index = 0; index < avatars.length; index++)
                    Positioned(
                      left: index * 22,
                      child: TtmProfileAvatar(
                        imageUrl: avatars[index].profileImageUrl,
                        size: 44,
                        borderWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: TtmSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    raid.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TtmTypography.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '참여자 ${participants.length}명',
                    style: TtmTypography.label.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTypingIndicator extends StatelessWidget {
  const _GroupTypingIndicator({required this.names});

  final String names;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: TtmSpacing.sm, left: 40),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TtmSpacing.md,
            vertical: TtmSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$names님이 입력 중...',
            style: TtmTypography.label.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
