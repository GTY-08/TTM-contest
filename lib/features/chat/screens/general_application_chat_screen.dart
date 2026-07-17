import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/display_nickname.dart';
import '../../../core/utils/restriction_error_message.dart';
import '../../../core/utils/ttm_snackbar.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/user_restriction.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/user_restriction_notice.dart';
import '../../match/providers/match_providers.dart';
import '../../match/models/general_request_applicant.dart';
import '../../match/providers/request_browse_providers.dart';
import '../../reports/report_dialog.dart';
import '../../reports/report_repository.dart';
import '../models/chat_message.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_thread_header.dart';
import '../widgets/counterpart_profile_sheet.dart';

class GeneralApplicationChatScreen extends ConsumerStatefulWidget {
  const GeneralApplicationChatScreen({
    super.key,
    required this.requestId,
    required this.applicationId,
  });

  final String requestId;
  final String applicationId;

  @override
  ConsumerState<GeneralApplicationChatScreen> createState() =>
      _GeneralApplicationChatScreenState();
}

enum _ImagePickMode { gallery, camera }

class _GeneralApplicationChatScreenState
    extends ConsumerState<GeneralApplicationChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _pickingImage = false;
  bool _withdrawing = false;
  bool _rewardBusy = false;
  bool _initialScrollDone = false;
  bool _showJumpToBottom = false;
  bool _forceScrollToEnd = false;
  Timer? _readMarkTimer;
  Timer? _readReceiptTimer;
  int _lastMessageCount = 0;
  String? _lastMessageId;
  String? _lastMineMessageId;
  String? _briefReadReceiptMessageId;
  ChatMessage? _pendingCounterpartMessage;
  bool _lastMineMessageWasUnread = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleMarkRead();
    });
  }

  @override
  void dispose() {
    _readMarkTimer?.cancel();
    _readReceiptTimer?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
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

  void _scheduleMarkRead() {
    _readMarkTimer?.cancel();
    _readMarkTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_markRead());
    });
  }

  Future<void> _markRead() async {
    try {
      await ref
          .read(matchingRepositoryProvider)
          .markGeneralApplicationChatRead(widget.applicationId);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _forceScrollToEnd = true;
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .sendGeneralApplicationMessage(
            applicationId: widget.applicationId,
            content: text,
          );
      if (!mounted) return;
      if (res['ok'] == true) {
        _composer.clear();
        await _markRead();
      } else {
        _forceScrollToEnd = false;
        _snack('메시지를 보내지 못했어요 (${res['reason'] ?? 'unknown'})');
      }
    } on PostgrestException catch (e) {
      _forceScrollToEnd = false;
      final restrictionMsg = restrictionErrorMessage(e);
      if (mounted) {
        _snack(restrictionMsg.isNotEmpty ? restrictionMsg : e.message);
      }
    } catch (e) {
      _forceScrollToEnd = false;
      if (mounted) _snack('메시지 전송 중 오류가 발생했어요: $e');
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
          .read(matchingRepositoryProvider)
          .sendGeneralApplicationImageMessages(
            applicationId: widget.applicationId,
            files: picked.map((x) => File(x.path)).toList(growable: false),
          );
      if (mounted) await _markRead();
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

  Future<void> _withdraw() async {
    if (_withdrawing) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('지원을 취소할까요?'),
        content: const Text('요청자가 아직 선택하지 않은 지원만 취소할 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니요'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지원 취소'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _withdrawing = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .withdrawGeneralRequestApplication(widget.applicationId);
      if (!mounted) return;
      if (res['ok'] == true) {
        _snack('지원이 취소되었습니다.');
        Navigator.of(context).maybePop();
      } else {
        _snack('지원 취소 실패 (${res['reason'] ?? 'unknown'})');
      }
    } catch (e) {
      if (mounted) _snack('지원 취소 중 오류가 발생했어요: $e');
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  Future<void> _proposeReward(num? currentReward) async {
    if (_rewardBusy) return;
    final controller = TextEditingController(
      text: currentReward == null
          ? ''
          : NumberFormat.decimalPattern('ko').format(currentReward),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('심부름비 제시'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '제안 금액',
            hintText: '예: 15000',
            suffixText: '원',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    final value = num.tryParse(controller.text.replaceAll(',', '').trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (ok != true || !mounted) return;
    if (value == null || value < 1000) {
      _snack('심부름비는 1,000원 이상으로 입력해 주세요.');
      return;
    }

    setState(() => _rewardBusy = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .proposeGeneralApplicationReward(
            applicationId: widget.applicationId,
            reward: value,
          );
      if (!mounted) return;
      if (res['ok'] == true) {
        _snack('새 심부름비를 제시했어요. 상대방 동의가 필요합니다.');
      } else {
        _snack(_rewardActionFailureKo(res['reason']?.toString()));
      }
    } catch (e) {
      if (mounted) _snack('금액 제시 중 오류가 발생했어요: $e');
    } finally {
      if (mounted) setState(() => _rewardBusy = false);
    }
  }

  Future<void> _acceptReward() async {
    if (_rewardBusy) return;
    setState(() => _rewardBusy = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .acceptGeneralApplicationReward(widget.applicationId);
      if (!mounted) return;
      if (res['ok'] == true) {
        _snack(
          res['agreement_ready'] == true
              ? '양측 동의가 완료됐어요. 요청자가 지원자를 선택할 수 있습니다.'
              : '제안 금액에 동의했어요.',
        );
      } else {
        _snack(_rewardActionFailureKo(res['reason']?.toString()));
      }
    } catch (e) {
      if (mounted) _snack('동의 처리 중 오류가 발생했어요: $e');
    } finally {
      if (mounted) setState(() => _rewardBusy = false);
    }
  }

  Future<void> _selectApplicant(GeneralApplicationAgreement agreement) async {
    if (_rewardBusy) return;
    if (!agreement.agreementReady || agreement.proposedReward == null) {
      _snack('양측이 마지막 제안 금액에 동의해야 선택할 수 있어요.');
      return;
    }
    final rewardText = NumberFormat.decimalPattern(
      'ko',
    ).format(agreement.proposedReward);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('지원자를 선택할까요?'),
        content: Text('양측이 $rewardText원에 동의했습니다. 이 지원자를 선택하면 바로 매칭이 시작됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('선택하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _rewardBusy = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .selectGeneralRequestApplicant(
            requestId: widget.requestId,
            workerId: agreement.workerId,
            negotiatedReward: agreement.proposedReward,
          );
      if (!mounted) return;
      if (res['ok'] == true) {
        ref.invalidate(requestStreamProvider(widget.requestId));
        ref.invalidate(generalRequestDetailProvider(widget.requestId));
        ref.invalidate(
          generalApplicationAgreementProvider(widget.applicationId),
        );
        ref.invalidate(myOpenGeneralRequestsProvider);
        ref.invalidate(myGeneralApplicationsProvider);
        ref.read(requestBrowseRefreshTickProvider.notifier).state++;
        _snack('작업자를 선택했어요.');
        context.go('${AppRoutes.requestRoot}/${widget.requestId}/active');
      } else {
        _snack(_selectFailureKo(res['reason']?.toString()));
      }
    } catch (e) {
      if (mounted) _snack('지원자 선택 중 오류가 발생했어요: $e');
    } finally {
      if (mounted) setState(() => _rewardBusy = false);
    }
  }

  String _rewardActionFailureKo(String? reason) {
    return switch (reason) {
      'invalid_reward' => '심부름비는 1,000원 이상이어야 해요.',
      'application_not_found' => '지원을 찾을 수 없어요.',
      'request_not_found' => '요청을 찾을 수 없어요.',
      'not_participant' => '이 협의에 참여한 사용자만 할 수 있어요.',
      'not_negotiable' => '이미 마감되었거나 협의할 수 없는 상태예요.',
      'no_proposed_reward' => '먼저 심부름비를 제시해 주세요.',
      _ => '처리하지 못했어요 (${reason ?? 'unknown'}).',
    };
  }

  String _selectFailureKo(String? reason) {
    return switch (reason) {
      'request_not_found' => '요청을 찾을 수 없어요.',
      'not_requester' => '요청자만 지원자를 선택할 수 있어요.',
      'not_selectable' => '이미 마감되었거나 선택할 수 없는 상태예요.',
      'application_not_found' => '지원을 찾을 수 없어요.',
      'agreement_required' => '요청자와 작업자가 마지막 제안 금액에 모두 동의해야 해요.',
      _ => '선택하지 못했어요 (${reason ?? 'unknown'}).',
    };
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
      await ref
          .read(matchingRepositoryProvider)
          .deleteGeneralApplicationMessage(message.id);
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('메시지를 삭제하지 못했어요: $e');
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final result = await showReportDialog(
      context: context,
      title: '메시지 신고',
      categories: ttmMessageReportCategories,
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(reportRepositoryProvider)
          .submitGeneralApplicationMessageReport(
            reportedUserId: message.senderId,
            requestId: widget.requestId,
            applicationId: widget.applicationId,
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

  String _messagePreview(ChatMessage message) {
    if (message.isImage) {
      final caption = message.content.trim();
      return caption.isEmpty ? '사진' : caption;
    }
    return message.content.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _snack(String message) {
    showTtmSnackBar(context, message);
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

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUserIdProvider);
    final messagesProvider = generalApplicationMessagesProvider(
      widget.applicationId,
    );
    final asyncMessages = ref.watch(messagesProvider);
    final detailAsync = ref.watch(
      generalRequestDetailProvider(widget.requestId),
    );
    final agreementAsync = ref.watch(
      generalApplicationAgreementProvider(widget.applicationId),
    );
    final counterpartAsync = ref.watch(
      generalApplicationCounterpartProvider(widget.applicationId),
    );
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final restrictions =
        ref.watch(myActiveRestrictionsProvider).valueOrNull ?? const [];
    final chatBlocked = restrictions.blocksChat;

    ref.listen<AsyncValue<({List<ChatMessage> messages, ChatReadState reads})>>(
      messagesProvider,
      (_, next) {
        next.whenData((bundle) {
          _handleMessagesUpdated(bundle, uid);
          if (uid != null &&
              bundle.reads.unreadFromCounterpart(
                    bundle.messages,
                    myUserId: uid,
                  ) >
                  0) {
            _scheduleMarkRead();
          }
        });
      },
    );

    final request = detailAsync.valueOrNull?.request;
    final isRequester = request?.requesterId == uid;
    final canWithdraw = !isRequester && request?.isOpen == true;
    final canSend = request?.isOpen == true && !chatBlocked;
    final agreement = agreementAsync.valueOrNull;
    final counterpart = counterpartAsync.valueOrNull;
    final counterpartName = ttmDisplayNickname(counterpart?.nickname);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(counterpart != null ? counterpartName : '지원자 채팅'),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: '사용자 신고',
            onPressed: counterpart == null
                ? null
                : () => _reportCounterpartUser(counterpart.id),
            icon: const Icon(Icons.flag_outlined),
          ),
          if (canWithdraw)
            TextButton(
              onPressed: _withdrawing ? null : _withdraw,
              child: _withdrawing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('지원 취소'),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (request != null && !request.isOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TtmSpacing.lg,
                    TtmSpacing.sm,
                    TtmSpacing.lg,
                    0,
                  ),
                  child: Text(
                    request.isMatched
                        ? '작업자가 선택된 게시글이에요. 진행 채팅은 매칭 채팅에서 이어집니다.'
                        : '종료된 게시글이에요. 대화는 읽기만 가능해요.',
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
                loading: counterpartAsync.isLoading,
                onProfileTap: counterpart == null
                    ? null
                    : () => _openCounterpartProfile(
                        counterpartIsRequester: !isRequester,
                        counterpart: counterpart,
                      ),
              ),
              if (request?.isOpen == true)
                _RewardAgreementPanel(
                  agreement: agreement,
                  myUserId: uid,
                  busy: _rewardBusy,
                  onPropose: () => _proposeReward(agreement?.proposedReward),
                  onAccept: agreement?.proposedReward == null
                      ? null
                      : _acceptReward,
                  onSelectApplicant:
                      isRequester &&
                          agreement != null &&
                          agreement.agreementReady
                      ? () => _selectApplicant(agreement)
                      : null,
                ),
              Expanded(
                child: asyncMessages.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(TtmSpacing.xl),
                      child: Text(
                        '채팅을 불러오지 못했어요.\n$e',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (bundle) {
                    final messages = bundle.messages;
                    if (messages.isEmpty) {
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
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.senderId == uid;
                        final prev = index > 0 ? messages[index - 1] : null;
                        final showName =
                            !isMine &&
                            (prev == null ||
                                prev.senderId != message.senderId ||
                                message.createdAt
                                        .difference(prev.createdAt)
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
                          isMine: isMine,
                          senderName: isMine ? '나' : counterpartName,
                          senderAvatarUrl: isMine
                              ? myProfile?.profileImageUrl
                              : counterpart?.profileImageUrl,
                          unreadByCounterpart:
                              isMine &&
                              !bundle.reads.isReadByCounterpart(message),
                          showReadReceipt:
                              isMine &&
                              _briefReadReceiptMessageId == message.id,
                          showSenderName: showName,
                          showAvatar: showAvatar,
                          onAvatarTap: isMine || counterpart == null
                              ? null
                              : () => _openCounterpartProfile(
                                  counterpartIsRequester: !isRequester,
                                  counterpart: counterpart,
                                ),
                          onLongPress: message.isDeleted
                              ? null
                              : (isMine
                                    ? () => _confirmDeleteMessage(message)
                                    : () => _reportMessage(message)),
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
                        onPressed: (!canSend || _sending || _pickingImage)
                            ? null
                            : _pickAndSendImage,
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
                            hintText: chatBlocked ? '채팅 기능 제한 중' : '메시지 입력',
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
  }
}

class _RewardAgreementPanel extends StatelessWidget {
  const _RewardAgreementPanel({
    required this.agreement,
    required this.myUserId,
    required this.busy,
    required this.onPropose,
    required this.onAccept,
    required this.onSelectApplicant,
  });

  final GeneralApplicationAgreement? agreement;
  final String? myUserId;
  final bool busy;
  final VoidCallback onPropose;
  final VoidCallback? onAccept;
  final VoidCallback? onSelectApplicant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reward = agreement?.proposedReward;
    final requesterAccepted = agreement?.requesterAcceptedAt != null;
    final workerAccepted = agreement?.workerAcceptedAt != null;
    final ready = agreement?.agreementReady == true;
    final proposedBy = agreement?.proposedBy?.toString();
    final mineProposed = myUserId != null && proposedBy == myUserId;
    final rewardLabel = reward == null
        ? '아직 제시된 최종 심부름비가 없어요'
        : '${NumberFormat.decimalPattern('ko').format(reward)}원';
    final status = ready
        ? '양측 동의 완료'
        : reward == null
        ? '금액을 먼저 제시해 주세요'
        : mineProposed
        ? '상대방 동의 대기'
        : '내 동의가 필요해요';
    final canAccept = reward != null && !ready && !mineProposed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        TtmSpacing.sm,
        TtmSpacing.lg,
        TtmSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(TtmSpacing.md),
        decoration: BoxDecoration(
          color: ready
              ? colors.primary.withValues(alpha: 0.10)
              : colors.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: ready
                ? colors.primary.withValues(alpha: 0.35)
                : colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ready ? Icons.verified_rounded : Icons.handshake_outlined,
                  color: ready ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: TtmSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rewardLabel,
                        style: TtmTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TtmTypography.label.copyWith(
                          color: ready
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (reward != null) ...[
              const SizedBox(height: TtmSpacing.sm),
              Row(
                children: [
                  _AgreementChip(label: '요청자', accepted: requesterAccepted),
                  const SizedBox(width: TtmSpacing.xs),
                  _AgreementChip(label: '작업자', accepted: workerAccepted),
                ],
              ),
            ],
            const SizedBox(height: TtmSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onPropose,
                    child: const Text('금액 제시'),
                  ),
                ),
                const SizedBox(width: TtmSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: busy || !canAccept ? null : onAccept,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('동의'),
                  ),
                ),
              ],
            ),
            if (onSelectApplicant != null) ...[
              const SizedBox(height: TtmSpacing.sm),
              FilledButton.icon(
                onPressed: busy ? null : onSelectApplicant,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('이 지원자 선택'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgreementChip extends StatelessWidget {
  const _AgreementChip({required this.label, required this.accepted});

  final String label;
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accepted
            ? colors.primary.withValues(alpha: 0.12)
            : colors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${accepted ? '동의' : '미동의'}',
        style: TtmTypography.label.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: accepted ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
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
