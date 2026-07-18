import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/display_nickname.dart';
import '../../../data/models/app_user.dart';
import '../../../data/providers/auth_providers.dart';
import '../../chat/models/chat_message.dart';
import '../../chat/widgets/chat_message_bubble.dart';
import '../../chat/widgets/chat_thread_header.dart';
import '../../chat/widgets/counterpart_profile_sheet.dart';
import '../providers/raid_providers.dart';

class RaidApplicationChatScreen extends ConsumerStatefulWidget {
  const RaidApplicationChatScreen({
    super.key,
    required this.raidId,
    required this.participantId,
  });

  final String raidId;
  final String participantId;

  @override
  ConsumerState<RaidApplicationChatScreen> createState() =>
      _RaidApplicationChatScreenState();
}

enum _ImagePickMode { gallery, camera }

class _RaidApplicationChatScreenState
    extends ConsumerState<RaidApplicationChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _pickingImage = false;
  bool _initialScrollDone = false;
  bool _initialScrollScheduled = false;
  bool _forceScrollToEnd = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_markRead());
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(
      raidApplicationChatContextProvider(widget.participantId),
    );
    final chatContext = contextAsync.valueOrNull;
    final messagesProvider = raidApplicationMessagesProvider(
      widget.participantId,
    );
    final messagesAsync = ref.watch(messagesProvider);
    final uid = ref.watch(authUserIdProvider);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final participant = chatContext?.participant;
    final isApplicant = chatContext?.isApplicant ?? false;
    final counterpart = chatContext == null
        ? null
        : AppUser.fromMap(chatContext.counterpart);
    final counterpartName = ttmDisplayNickname(counterpart?.nickname);
    final readOnly = chatContext?.isReadOnly ?? true;

    ref.listen<AsyncValue<({List<ChatMessage> messages, ChatReadState reads})>>(
      messagesProvider,
      (_, next) {
        next.whenData((bundle) {
          final hasNewMessage = bundle.messages.length > _lastMessageCount;
          final shouldScroll =
              !_initialScrollDone ||
              _forceScrollToEnd ||
              (_isNearBottom && hasNewMessage);
          _lastMessageCount = bundle.messages.length;
          if (uid != null &&
              bundle.reads.unreadFromCounterpart(
                    bundle.messages,
                    myUserId: uid,
                  ) >
                  0) {
            unawaited(_markRead());
          }
          if (shouldScroll) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToEnd(jump: !_initialScrollDone);
              _initialScrollDone = true;
              _forceScrollToEnd = false;
            });
          }
        });
      },
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(counterpart == null ? '지원자 채팅' : counterpartName),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatThreadHeader(
            isRequester: isApplicant,
            counterpart: counterpart,
            loading: contextAsync.isLoading && counterpart == null,
            counterpartRoleLabel: isApplicant ? '매칭 운영자' : '지원자',
            onProfileTap: counterpart == null
                ? null
                : () => _openCounterpartProfile(
                    counterpart: counterpart,
                    counterpartIsRequester: isApplicant,
                  ),
          ),
          if (participant?.applicationMessage?.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.fromLTRB(
                TtmSpacing.lg,
                TtmSpacing.sm,
                TtmSpacing.lg,
                0,
              ),
              padding: const EdgeInsets.all(TtmSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '지원 메시지\n${participant!.applicationMessage}',
                style: TtmTypography.body,
              ),
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
                '종료된 지원이에요. 대화는 읽기만 가능해요.',
                textAlign: TextAlign.center,
                style: TtmTypography.label.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(TtmSpacing.xl),
                  child: Text(
                    '채팅을 불러오지 못했어요.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (bundle) {
                final messages = bundle.messages;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      readOnly ? '저장된 메시지가 없어요.' : '첫 메시지를 남겨 보세요.',
                      style: TtmTypography.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                _ensureInitialScroll();
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TtmSpacing.lg,
                    vertical: TtmSpacing.sm,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = message.senderId == uid;
                    final previous = index > 0 ? messages[index - 1] : null;
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
                        messages[index + 1].senderId != message.senderId ||
                        messages[index + 1].createdAt
                                .difference(message.createdAt)
                                .inMinutes >
                            5;
                    return ChatMessageBubble(
                      message: message,
                      isMine: mine,
                      senderName: mine ? '나' : counterpartName,
                      senderAvatarUrl: mine
                          ? myProfile?.profileImageUrl
                          : counterpart?.profileImageUrl,
                      unreadByCounterpart:
                          mine && !bundle.reads.isReadByCounterpart(message),
                      showSenderName: showName,
                      showAvatar: showAvatar,
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
                      onPressed: _sending || _pickingImage
                          ? null
                          : _pickAndSendImage,
                      tooltip: '사진 보내기',
                      icon: _pickingImage
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                          hintText: '메시지 입력',
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
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TtmSpacing.sm),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
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
    );
  }

  bool get _isNearBottom {
    if (!_scroll.hasClients) return true;
    final position = _scroll.position;
    return position.maxScrollExtent - position.pixels < 180;
  }

  void _ensureInitialScroll() {
    if (_initialScrollDone || _initialScrollScheduled) return;
    _initialScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialScrollScheduled = false;
      if (!mounted || !_scroll.hasClients || _initialScrollDone) return;
      _scrollToEnd(jump: true);
      _initialScrollDone = true;
    });
  }

  void _scrollToEnd({required bool jump}) {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (jump) {
      _scroll.jumpTo(end);
    } else {
      unawaited(
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _openCounterpartProfile({
    required AppUser counterpart,
    required bool counterpartIsRequester,
  }) {
    unawaited(
      showCounterpartProfileSheet(
        context,
        user: counterpart,
        counterpartIsRequester: counterpartIsRequester,
      ),
    );
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    _forceScrollToEnd = true;
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .sendApplicationMessage(
            participantId: widget.participantId,
            content: content,
          );
      if (!mounted) return;
      if (result['ok'] == true) {
        _composer.clear();
        await _markRead();
      } else {
        _forceScrollToEnd = false;
        _show('메시지를 보내지 못했어요 (${result['reason'] ?? 'unknown'}).');
      }
    } on PostgrestException catch (error) {
      _forceScrollToEnd = false;
      if (mounted) _show(error.message);
    } catch (error) {
      _forceScrollToEnd = false;
      if (mounted) _show('메시지를 보내지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_pickingImage || _sending) return;
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
          .sendApplicationImageMessages(
            participantId: widget.participantId,
            files: picked.map((image) => File(image.path)).toList(),
          );
      if (mounted) await _markRead();
    } on PostgrestException catch (error) {
      _forceScrollToEnd = false;
      if (mounted) _show(error.message);
    } catch (error) {
      _forceScrollToEnd = false;
      if (mounted) _show('사진을 보내지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await ref
          .read(raidRepositoryProvider)
          .markApplicationChatRead(widget.participantId);
    } catch (_) {}
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
