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
import '../../match/models/match_request.dart';
import '../../match/providers/match_providers.dart';
import '../../reports/report_dialog.dart';
import '../../reports/report_repository.dart';
import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_thread_header.dart';
import '../widgets/counterpart_profile_sheet.dart';
import '../../../shared/widgets/user_restriction_notice.dart';

/// 매칭 진행 중 DM 전용 화면.
class MatchChatScreen extends ConsumerStatefulWidget {
  const MatchChatScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<MatchChatScreen> createState() => _MatchChatScreenState();
}

enum _ImagePickMode { gallery, camera }

class _MatchChatScreenState extends ConsumerState<MatchChatScreen> {
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  bool _sending = false;
  bool _pickingImage = false;
  Timer? _readMarkTimer;
  Timer? _readReceiptTimer;
  Timer? _typingStopTimer;
  Timer? _counterpartTypingExpireTimer;
  RealtimeChannel? _typingChannel;
  bool _initialScrollDone = false;
  bool _showJumpToBottom = false;
  bool _counterpartTyping = false;
  int _lastMessageCount = 0;
  String? _lastMessageId;
  String? _lastMineMessageId;
  String? _briefReadReceiptMessageId;
  ChatMessage? _pendingCounterpartMessage;
  bool _lastMineMessageWasUnread = false;
  bool _forceScrollToEnd = false;
  bool _sentTyping = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScrollChanged);
    _composer.addListener(_handleComposerChanged);
    _subscribeTyping();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleMarkChatRead();
    });
  }

  @override
  void dispose() {
    _readMarkTimer?.cancel();
    _readReceiptTimer?.cancel();
    _typingStopTimer?.cancel();
    _counterpartTypingExpireTimer?.cancel();
    final channel = _typingChannel;
    if (channel != null) {
      unawaited(_sendTyping(false));
      unawaited(ref.read(chatRepositoryProvider).removeChannel(channel));
    }
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _subscribeTyping() {
    _typingChannel = ref
        .read(chatRepositoryProvider)
        .watchTyping(
          requestId: widget.requestId,
          onTyping: (userId, isTyping) {
            final uid = ref.read(authUserIdProvider);
            if (!mounted || userId == uid) return;
            _counterpartTypingExpireTimer?.cancel();
            setState(() => _counterpartTyping = isTyping);
            if (isTyping) {
              _counterpartTypingExpireTimer = Timer(
                const Duration(seconds: 4),
                () {
                  if (mounted) setState(() => _counterpartTyping = false);
                },
              );
            }
          },
        );
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
          .read(chatRepositoryProvider)
          .sendTyping(channel: channel, isTyping: isTyping);
    } catch (_) {}
  }

  void _handleScrollChanged() {
    if (!_scroll.hasClients) return;
    final away = _distanceFromBottom() > 180;
    if (away == _showJumpToBottom) return;
    setState(() {
      _showJumpToBottom = away;
      if (!away) _pendingCounterpartMessage = null;
    });
  }

  double _distanceFromBottom() {
    if (!_scroll.hasClients) return 0;
    final pos = _scroll.position;
    return (pos.maxScrollExtent - pos.pixels).clamp(0, double.infinity);
  }

  bool get _isAwayFromBottom => _distanceFromBottom() > 180;

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      setState(() {
        _pendingCounterpartMessage = null;
        _showJumpToBottom = false;
      });
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scheduleMarkChatRead() {
    _readMarkTimer?.cancel();
    _readMarkTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_markChatRead());
    });
  }

  Future<void> _markChatRead() async {
    try {
      await ref.read(chatRepositoryProvider).markAsRead(widget.requestId);
    } catch (_) {}
  }

  Future<void> _pickAndSendImage(MatchRequest req) async {
    if (_pickingImage || _sending || !req.isMatched) return;
    final mode = await showModalBottomSheet<_ImagePickMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              subtitle: const Text('여러 장을 한 번에 보낼 수 있어요'),
              onTap: () => Navigator.pop(context, _ImagePickMode.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, _ImagePickMode.camera),
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
      if (mode == _ImagePickMode.gallery) {
        picked = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
      } else {
        final camera = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        picked = camera == null ? <XFile>[] : <XFile>[camera];
      }
      if (picked.isEmpty || !mounted) {
        _forceScrollToEnd = false;
        return;
      }

      await ref
          .read(chatRepositoryProvider)
          .sendImageMessages(
            requestId: widget.requestId,
            files: picked.map((x) => File(x.path)).toList(growable: false),
          );
      if (mounted) await _markChatRead();
    } on PostgrestException catch (e) {
      _forceScrollToEnd = false;
      final restrictionMsg = restrictionErrorMessage(e);
      if (mounted) {
        _snack(restrictionMsg.isNotEmpty ? restrictionMsg : e.message);
      }
    } catch (e) {
      _forceScrollToEnd = false;
      if (mounted) _snack('사진을 보내지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final trimmed = _composer.text.trim();
    if (trimmed.isEmpty) return;

    setState(() => _sending = true);
    _forceScrollToEnd = true;
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(requestId: widget.requestId, content: trimmed);
      if (mounted) {
        _composer.clear();
        await _markChatRead();
      }
    } on PostgrestException catch (e) {
      _forceScrollToEnd = false;
      final restrictionMsg = restrictionErrorMessage(e);
      if (mounted) {
        _snack(restrictionMsg.isNotEmpty ? restrictionMsg : e.message);
      }
    } catch (e) {
      _forceScrollToEnd = false;
      if (mounted) _snack('전송하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠어요? 삭제 후에는 “삭제된 메시지입니다.”로 표시됩니다.'),
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
    if (ok != true || !mounted) return;

    try {
      await ref.read(chatRepositoryProvider).deleteMyMessage(message.id);
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('메시지를 삭제하지 못했어요: $e');
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final result = await showReportDialog(
      context: context,
      title: '메세지 신고',
      categories: ttmMessageReportCategories,
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(reportRepositoryProvider)
          .submitMessageReport(
            reportedUserId: message.senderId,
            requestId: widget.requestId,
            messageId: message.id,
            category: result.category,
            messageSnapshot: _messagePreview(message),
            description: result.description,
          );
      if (mounted) _snack('신고가 접수됐어요.');
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('신고를 접수하지 못했어요: $e');
    }
  }

  String _messagePreview(ChatMessage message) {
    if (message.isImage) {
      final caption = message.content.trim();
      return caption.isEmpty ? '사진' : caption;
    }
    return message.content.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _snack(String msg) {
    showTtmSnackBar(context, msg);
  }

  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      if (!_initialScrollDone || force) {
        _pendingCounterpartMessage = null;
        _showJumpToBottom = false;
        _scroll.jumpTo(pos.maxScrollExtent);
        _initialScrollDone = true;
        return;
      }
      // 이미 스크롤 위치가 하단 근처(150px 이내)일 때만 자동 스크롤.
      // 사용자가 위로 올려 이전 대화를 보는 중이면 강제 이동하지 않는다.
      if ((pos.maxScrollExtent - pos.pixels) < 150) {
        _pendingCounterpartMessage = null;
        _showJumpToBottom = false;
        _scroll.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleMessagesUpdated(
    ({List<ChatMessage> messages, ChatReadState reads}) bundle,
    String? uid,
  ) {
    final msgs = bundle.messages;
    final lastMessageId = msgs.isEmpty ? null : msgs.last.id;
    final messagesChanged =
        msgs.length != _lastMessageCount || lastMessageId != _lastMessageId;

    if (messagesChanged) {
      final shouldForce = _forceScrollToEnd;
      _forceScrollToEnd = false;
      final latest = msgs.isEmpty ? null : msgs.last;
      if (_initialScrollDone &&
          uid != null &&
          latest != null &&
          latest.senderId != uid &&
          _isAwayFromBottom) {
        setState(() {
          _pendingCounterpartMessage = latest;
          _showJumpToBottom = true;
        });
      }
      _scrollToEnd(force: shouldForce);
    }

    if (uid != null) {
      ChatMessage? lastMine;
      for (final message in msgs.reversed) {
        if (message.senderId == uid) {
          lastMine = message;
          break;
        }
      }

      final lastMineId = lastMine?.id;
      final lastMineUnread =
          lastMine != null && !bundle.reads.isReadByCounterpart(lastMine);
      final justRead =
          lastMineId != null &&
          lastMineId == _lastMineMessageId &&
          _lastMineMessageWasUnread &&
          !lastMineUnread;

      if (justRead) {
        _showBriefReadReceipt(lastMineId);
      } else if (lastMineId != _lastMineMessageId) {
        _clearBriefReadReceipt();
      }

      _lastMineMessageId = lastMineId;
      _lastMineMessageWasUnread = lastMineUnread;
    }

    _lastMessageCount = msgs.length;
    _lastMessageId = lastMessageId;
  }

  void _showBriefReadReceipt(String messageId) {
    _readReceiptTimer?.cancel();
    if (mounted) {
      setState(() => _briefReadReceiptMessageId = messageId);
    } else {
      _briefReadReceiptMessageId = messageId;
    }
    _readReceiptTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _briefReadReceiptMessageId != messageId) return;
      setState(() => _briefReadReceiptMessageId = null);
    });
  }

  void _clearBriefReadReceipt() {
    _readReceiptTimer?.cancel();
    if (_briefReadReceiptMessageId == null) return;
    if (mounted) {
      setState(() => _briefReadReceiptMessageId = null);
    } else {
      _briefReadReceiptMessageId = null;
    }
  }

  void _openCounterpartProfile({
    required bool counterpartIsRequester,
    required AppUser counterpart,
  }) {
    unawaited(
      showCounterpartProfileSheet(
        context,
        user: counterpart,
        counterpartIsRequester: counterpartIsRequester,
      ),
    );
  }

  Future<void> _reportCounterpartUser(String counterpartId) async {
    if (counterpartId.isEmpty) return;
    final result = await showReportDialog(
      context: context,
      title: '사용자 신고',
      categories: ttmUserReportCategories,
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(reportRepositoryProvider)
          .submitUserReport(
            reportedUserId: counterpartId,
            requestId: widget.requestId,
            category: result.category,
            description: result.description,
          );
      if (mounted) _snack('신고가 접수됐어요.');
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('신고를 접수하지 못했어요: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUserIdProvider);
    final asyncReq = ref.watch(requestStreamProvider(widget.requestId));

    ref.listen(messagesStreamProvider(widget.requestId), (_, next) {
      next.whenData((bundle) {
        _handleMessagesUpdated(bundle, uid);
        if (uid != null &&
            bundle.reads.unreadFromCounterpart(bundle.messages, myUserId: uid) >
                0) {
          _scheduleMarkChatRead();
        }
      });
    });

    return asyncReq.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('메시지')),
        body: Center(child: Text('불러오지 못했어요.\n$e')),
      ),
      data: (req) {
        if (req == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('메시지')),
            body: const Center(child: Text('요청을 찾을 수 없어요.')),
          );
        }

        final isRequester = uid == req.requesterId;
        final counterpartId = isRequester
            ? (req.workerId ?? '')
            : req.requesterId;
        final counterpartAsync = ref.watch(
          matchCounterpartProvider((
            requestId: widget.requestId,
            counterpartId: counterpartId,
          )),
        );
        final counterpart = counterpartAsync.valueOrNull;
        final counterpartLoading = counterpartAsync.isLoading;
        final myProfile = ref.watch(myProfileProvider).valueOrNull;
        final restrictions =
            ref.watch(myActiveRestrictionsProvider).valueOrNull ?? const [];
        final chatBlocked = restrictions.blocksChat;
        final canSend = req.isMatched && !chatBlocked;
        final counterpartName = ttmDisplayNickname(counterpart?.nickname);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(counterpart != null ? counterpartName : '메시지'),
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                tooltip: '사용자 신고',
                onPressed: counterpartId.isEmpty
                    ? null
                    : () => _reportCounterpartUser(counterpartId),
                icon: const Icon(Icons.flag_outlined),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (req.isCompleted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TtmSpacing.lg,
                        TtmSpacing.sm,
                        TtmSpacing.lg,
                        0,
                      ),
                      child: Text(
                        '종료된 심부름이에요. 대화는 읽기만 가능해요.',
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
                  ChatThreadHeader(
                    isRequester: isRequester,
                    counterpart: counterpart,
                    loading: counterpartLoading,
                    onProfileTap: counterpart == null
                        ? null
                        : () => _openCounterpartProfile(
                            counterpartIsRequester: !isRequester,
                            counterpart: counterpart,
                          ),
                  ),
                  Expanded(
                    child: ref
                        .watch(messagesStreamProvider(widget.requestId))
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('메시지: $e')),
                          data: (bundle) {
                            final msgs = bundle.messages;
                            final reads = bundle.reads;

                            if (msgs.isEmpty && !_counterpartTyping) {
                              return Center(
                                child: Text(
                                  canSend ? '첫 메시지를 남겨 보세요.' : '저장된 메시지가 없어요.',
                                  style: TtmTypography.body.copyWith(
                                    fontSize: 15,
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
                                  msgs.length + (_counterpartTyping ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == msgs.length) {
                                  return const _TypingIndicatorBubble();
                                }
                                final m = msgs[i];
                                final mine = m.senderId == uid;
                                final prev = i > 0 ? msgs[i - 1] : null;
                                final showName =
                                    !mine &&
                                    (prev == null ||
                                        prev.senderId != m.senderId ||
                                        m.createdAt
                                                .difference(prev.createdAt)
                                                .inMinutes >
                                            5);
                                final showAvatar =
                                    i == msgs.length - 1 ||
                                    msgs[i + 1].senderId != m.senderId ||
                                    msgs[i + 1].createdAt
                                            .difference(m.createdAt)
                                            .inMinutes >
                                        5;

                                return ChatMessageBubble(
                                  message: m,
                                  isMine: mine,
                                  senderName: mine ? '나' : counterpartName,
                                  senderAvatarUrl: mine
                                      ? myProfile?.profileImageUrl
                                      : counterpart?.profileImageUrl,
                                  unreadByCounterpart:
                                      mine && !reads.isReadByCounterpart(m),
                                  showReadReceipt:
                                      mine &&
                                      _briefReadReceiptMessageId == m.id,
                                  showSenderName: showName,
                                  showAvatar: showAvatar,
                                  onAvatarTap: mine || counterpart == null
                                      ? null
                                      : () => _openCounterpartProfile(
                                          counterpartIsRequester: !isRequester,
                                          counterpart: counterpart,
                                        ),
                                  onLongPress: m.isDeleted
                                      ? null
                                      : (mine
                                            ? () => _confirmDeleteMessage(m)
                                            : () => _reportMessage(m)),
                                );
                              },
                            );
                          },
                        ),
                  ),
                  if (req.isMatched)
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
                              onPressed: (!canSend || _sending || _pickingImage)
                                  ? null
                                  : () => _pickAndSendImage(req),
                              tooltip: '사진 보내기',
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
                                textInputAction: TextInputAction.newline,
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
                                enabled: canSend,
                                onSubmitted: (_) => _send(),
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
              if (_showJumpToBottom || _pendingCounterpartMessage != null)
                _BottomChatJumpOverlay(
                  message: _pendingCounterpartMessage,
                  previewBuilder: _messagePreview,
                  onTap: _jumpToBottom,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomChatJumpOverlay extends StatelessWidget {
  const _BottomChatJumpOverlay({
    required this.message,
    required this.previewBuilder,
    required this.onTap,
  });

  final ChatMessage? message;
  final String Function(ChatMessage message) previewBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preview = message == null ? null : previewBuilder(message!);

    return Positioned(
      left: TtmSpacing.lg,
      right: TtmSpacing.lg,
      bottom: 86,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: colors.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(999),
          shadowColor: Colors.black.withValues(alpha: 0.18),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: preview == null ? 10 : TtmSpacing.md,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: colors.primary,
                    ),
                    if (preview != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TtmTypography.body.copyWith(
                            fontSize: 13,
                            color: colors.onSurface,
                          ),
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
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: TtmSpacing.lg,
        right: TtmSpacing.lg,
        bottom: TtmSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 40),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TtmSpacing.md,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final phase = (_controller.value * 3 - index).clamp(0, 1);
                    final opacity = 0.35 + (phase * 0.65);
                    final dy = -3.0 * phase;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
