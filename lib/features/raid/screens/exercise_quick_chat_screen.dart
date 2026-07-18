import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/display_nickname.dart';
import '../../../core/utils/pedestrian_location.dart';
import '../../../data/models/app_user.dart';
import '../../../data/providers/auth_providers.dart';
import '../../chat/models/chat_message.dart';
import '../../chat/widgets/chat_message_bubble.dart';
import '../../chat/widgets/chat_thread_header.dart';
import '../../chat/widgets/counterpart_profile_sheet.dart';
import '../models/exercise_matching_models.dart';
import '../providers/raid_providers.dart';
import '../widgets/quick_match_live_map.dart';

class ExerciseQuickChatScreen extends ConsumerStatefulWidget {
  const ExerciseQuickChatScreen({super.key, required this.quickMatchId});

  final String quickMatchId;

  @override
  ConsumerState<ExerciseQuickChatScreen> createState() =>
      _ExerciseQuickChatScreenState();
}

enum _ImagePickMode { gallery, camera }

class _ExerciseQuickChatScreenState
    extends ConsumerState<ExerciseQuickChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<Position>? _locationSubscription;
  String? _trackingMatchId;
  bool _sending = false;
  bool _pickingImage = false;
  bool _mapExpanded = true;
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
    _locationSubscription?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUserIdProvider);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final matchAsync = ref.watch(
      quickMatchChatContextProvider(widget.quickMatchId),
    );
    final match = matchAsync.valueOrNull;
    if (match?.isMatched == true && _trackingMatchId != match!.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startLocationTracking(match));
      });
    }

    final messagesProvider = quickMatchMessagesProvider(widget.quickMatchId);
    final messagesAsync = ref.watch(messagesProvider);
    final locationsAsync = ref.watch(
      quickMatchLocationsProvider(widget.quickMatchId),
    );
    final locations = locationsAsync.valueOrNull ?? const [];
    final myLocation = _locationFor(locations, uid);
    final partnerId = match == null || uid == null
        ? null
        : (match.requesterId == uid ? match.matchedUserId : match.requesterId);
    final partnerLocation = _locationFor(locations, partnerId);
    final counterpart = _counterpartFrom(match?.partner);
    final counterpartName = ttmDisplayNickname(counterpart?.nickname);
    final canSend = match?.isMatched == true;

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
        title: Text(counterpart == null ? '운동 파트너 채팅' : counterpartName),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatThreadHeader(
            isRequester: match?.requesterId == uid,
            counterpart: counterpart,
            loading: matchAsync.isLoading && counterpart == null,
            counterpartRoleLabel: '1:1 운동 파트너',
            onProfileTap: counterpart == null
                ? null
                : () => _openCounterpartProfile(
                    counterpart: counterpart,
                    counterpartIsRequester: match?.requesterId != uid,
                  ),
          ),
          InkWell(
            onTap: () => setState(() => _mapExpanded = !_mapExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TtmSpacing.lg,
                vertical: TtmSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: TtmSpacing.sm),
                  const Expanded(
                    child: Text(
                      '실시간 위치',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    partnerLocation == null ? '상대 위치 대기 중' : '위치 공유 중',
                    style: TtmTypography.label.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    _mapExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _mapExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: QuickMatchLiveMap(
              meetingLatitude: match?.latitude,
              meetingLongitude: match?.longitude,
              myLatitude: myLocation?.latitude,
              myLongitude: myLocation?.longitude,
              partnerLatitude: partnerLocation?.latitude,
              partnerLongitude: partnerLocation?.longitude,
              partnerLabel: counterpartName,
              height: 250,
            ),
            secondChild: const SizedBox.shrink(),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(TtmSpacing.xl),
                  child: Text(
                    '메시지를 불러오지 못했어요.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (bundle) {
                final messages = bundle.messages;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      canSend ? '첫 메시지를 남겨 보세요.' : '종료된 매칭이에요.',
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
                    onPressed: !canSend || _sending || _pickingImage
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
                      enabled: canSend,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: canSend ? '메시지 입력' : '종료된 매칭입니다',
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
                    onPressed: !canSend || _sending ? null : _send,
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

  ExerciseQuickMatchLocation? _locationFor(
    List<ExerciseQuickMatchLocation> locations,
    String? userId,
  ) {
    if (userId == null) return null;
    for (final location in locations) {
      if (location.userId == userId) return location;
    }
    return null;
  }

  AppUser? _counterpartFrom(Map<String, dynamic>? map) {
    if (map == null || map['id'] == null) return null;
    return AppUser.fromMap(map);
  }

  Future<void> _startLocationTracking(ExerciseQuickMatch match) async {
    if (_trackingMatchId == match.id) return;
    _trackingMatchId = match.id;
    await _locationSubscription?.cancel();
    final initial = await TtmPedestrianLocation.obtainPosition();
    if (initial != null) await _publishLocation(match.id, initial);
    if (!mounted || _trackingMatchId != match.id) return;
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: TtmPedestrianLocation.streamSettings(),
        ).listen((position) {
          if (!TtmPedestrianLocation.isReliableForPublish(position)) return;
          unawaited(_publishLocation(match.id, position));
        });
  }

  Future<void> _publishLocation(String matchId, Position position) async {
    try {
      await ref
          .read(raidRepositoryProvider)
          .updateQuickMatchLocation(
            quickMatchId: matchId,
            location: ExerciseLocationSnapshot(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracyMeters: position.accuracy,
              capturedAt: position.timestamp,
            ),
          );
    } catch (_) {}
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

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _forceScrollToEnd = true;
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .sendQuickMessage(widget.quickMatchId, text);
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
          .sendQuickImageMessages(
            quickMatchId: widget.quickMatchId,
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
          .markQuickMatchChatRead(widget.quickMatchId);
    } catch (_) {}
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

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
