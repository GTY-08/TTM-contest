import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/constants/matching_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../features/chat/widgets/match_role_badge.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../../data/providers/auth_providers.dart';
import '../models/general_request_applicant.dart';
import '../models/match_request.dart';
import '../providers/match_providers.dart';
import '../providers/request_browse_providers.dart';
import '../widgets/radius_pulse.dart';
import '../widgets/stage_progress_bar.dart';

/// 요청자가 매칭을 기다리는 핵심 화면.
///
/// - 가운데 펄스로 "주변에 알리고 있어요" 라는 느낌
/// - 위에 10단계 progress bar
/// - 다음 단계까지 남은 초 카운트다운 + 호출 보조 tick
/// - status 가 matched / failed / cancelled 로 바뀌면 자동 전환
class MatchWaitingScreen extends ConsumerStatefulWidget {
  const MatchWaitingScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<MatchWaitingScreen> createState() => _MatchWaitingScreenState();
}

class _MatchWaitingScreenState extends ConsumerState<MatchWaitingScreen> {
  Timer? _ticker;
  int _secondsToNext = 0;
  bool _cancelling = false;
  bool _terminalShown = false;
  int _pollTick = 0;
  String? _selectingWorkerId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final req = await ref
            .read(matchingRepositoryProvider)
            .fetchRequest(widget.requestId);
        if (req?.isQuickMatching == true) {
          await ref
              .read(prefsProvider)
              .setWaitingMatchRequestId(widget.requestId);
        } else {
          await ref.read(prefsProvider).clearWaitingMatchRequestId();
        }
      } catch (_) {
        await ref
            .read(prefsProvider)
            .setWaitingMatchRequestId(widget.requestId);
      }
    });
  }

  Future<void> _clearWaitingFlag() async {
    await ref.read(prefsProvider).clearWaitingMatchRequestId();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _onTick() async {
    if (!mounted) return;

    MatchRequest? req = ref
        .read(requestStreamProvider(widget.requestId))
        .asData
        ?.value;

    // Realtime 미수신 시 REST 로 종료 상태 보강 (요청자 매칭 성공 전환 버그 대응)
    _pollTick++;
    if (!_terminalShown && (_pollTick % 3 == 0 || req == null || !req.isOpen)) {
      try {
        req = await ref
            .read(matchingRepositoryProvider)
            .fetchRequest(widget.requestId);
      } catch (_) {
        // 스트림 값만 사용
      }
    }

    if (req == null) return;
    if (!req.isOpen) {
      _handleTerminal(req);
      return;
    }
    if (req.isGeneralMatching && _pollTick % 5 == 0) {
      unawaited(_clearWaitingFlag());
      ref.invalidate(generalRequestApplicantsProvider(widget.requestId));
      return;
    }

    final remaining = req.nextAdvanceAt.difference(DateTime.now()).inSeconds;
    if (mounted) setState(() => _secondsToNext = remaining > 0 ? remaining : 0);

    if (remaining <= 0) {
      try {
        await ref
            .read(matchingRepositoryProvider)
            .advanceStage(widget.requestId);
      } catch (_) {
        // 멱등 — 다음 틱에서 다시 시도
      }
    }
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('요청을 취소할까요?'),
        content: const Text('지금 취소하면 매칭이 즉시 중단돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .cancelRequest(widget.requestId);
      if (!mounted) return;
      if (res['ok'] == true) {
        await _clearWaitingFlag();
        if (!mounted) return;
        _snack(res['message']?.toString() ?? '취소가 완료되었습니다.');
        context.go(AppRoutes.home);
      } else {
        _snack('취소하지 못했어요 (${res['reason'] ?? 'unknown'})');
      }
    } catch (e) {
      if (mounted) _snack('취소 중 오류가 발생했어요.');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _selectApplicant(GeneralRequestApplicant applicant) async {
    if (_selectingWorkerId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작업자를 선택할까요?'),
        content: Text(
          applicant.agreementReady
              ? '양측이 ${NumberFormat.decimalPattern('ko').format(applicant.proposedReward)}원에 동의했습니다. 이 지원자를 선택하면 바로 매칭이 시작됩니다.'
              : '요청자와 작업자가 마지막 제안 금액에 모두 동의해야 선택할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('선택하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!applicant.agreementReady) {
      _snack('양측이 마지막 제안 금액에 동의해야 선택할 수 있어요.');
      return;
    }

    setState(() => _selectingWorkerId = applicant.workerId);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .selectGeneralRequestApplicant(
            requestId: widget.requestId,
            workerId: applicant.workerId,
            negotiatedReward: applicant.proposedReward,
          );
      if (!mounted) return;
      if (res['ok'] == true) {
        ref.invalidate(requestStreamProvider(widget.requestId));
        ref.invalidate(generalRequestDetailProvider(widget.requestId));
        ref.invalidate(myOpenGeneralRequestsProvider);
        ref.invalidate(myGeneralApplicationsProvider);
        ref.read(requestBrowseRefreshTickProvider.notifier).state++;
        _snack('작업자를 선택했어요.');
        context.go('${AppRoutes.requestRoot}/${widget.requestId}/active');
      } else {
        _snack('선택하지 못했어요 (${res['reason'] ?? 'unknown'})');
      }
    } catch (e) {
      if (mounted) _snack('선택 중 오류가 발생했어요: $e');
    } finally {
      if (mounted) setState(() => _selectingWorkerId = null);
    }
  }

  void _handleTerminal(MatchRequest req) {
    if (_terminalShown) return;
    if (req.isOpen) return;
    _terminalShown = true;
    unawaited(_clearWaitingFlag());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      switch (req.status) {
        case 'matched':
          await _showMatchedDialog();
          break;
        case 'failed':
          await _showFailedDialog();
          break;
        case 'cancelled':
          await _showCancelledDialog();
          break;
      }
    });
  }

  Future<void> _showMatchedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _MatchedDialog(isRequester: true),
    );
    if (!mounted) return;
    context.go('${AppRoutes.requestRoot}/${widget.requestId}/active');
  }

  Future<void> _showFailedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('매칭에 실패했어요'),
        content: const Text(
          '10단계까지 알렸지만 수락한 사람이 없었어요.\n다시 만들거나 보상·반경을 조정해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  Future<void> _showCancelledDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('요청이 취소됐어요'),
        content: const Text('매칭 대기 중이던 요청이 취소되어 홈으로 이동합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final async = ref.watch(requestStreamProvider(widget.requestId));
    final currentReq = async.asData?.value;
    final isGeneral = currentReq?.isGeneralMatching == true;

    ref.listen<AsyncValue<MatchRequest?>>(
      requestStreamProvider(widget.requestId),
      (_, next) {
        next.whenData((req) {
          if (req != null) _handleTerminal(req);
        });
      },
    );

    return PopScope(
      canPop: isGeneral,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _snack('매칭 중에는 나갈 수 없어요. 취소하려면 아래 「요청 취소」를 눌러 주세요.');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isGeneral ? '일반 매칭 게시글' : '매칭 중'),
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: isGeneral,
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(TtmSpacing.xl),
                child: Text(
                  '요청을 불러오지 못했어요.\n$error',
                  textAlign: TextAlign.center,
                  style: TtmTypography.body.copyWith(
                    fontSize: 15,
                    color: colors.error,
                  ),
                ),
              ),
            ),
            data: (req) {
              if (req == null) {
                return Center(
                  child: Text(
                    '요청을 찾을 수 없어요.',
                    style: TtmTypography.body.copyWith(
                      fontSize: 15,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                );
              }
              _handleTerminal(req);
              return _MatchWaitingBody(
                request: req,
                secondsToNext: _secondsToNext,
                onCancel: _cancel,
                cancelling: _cancelling,
                applicants: ref.watch(
                  generalRequestApplicantsProvider(widget.requestId),
                ),
                selectingWorkerId: _selectingWorkerId,
                onSelectApplicant: _selectApplicant,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MatchWaitingBody extends StatelessWidget {
  const _MatchWaitingBody({
    required this.request,
    required this.secondsToNext,
    required this.onCancel,
    required this.cancelling,
    required this.applicants,
    required this.selectingWorkerId,
    required this.onSelectApplicant,
  });

  final MatchRequest request;
  final int secondsToNext;
  final VoidCallback onCancel;
  final bool cancelling;
  final AsyncValue<List<GeneralRequestApplicant>> applicants;
  final String? selectingWorkerId;
  final ValueChanged<GeneralRequestApplicant> onSelectApplicant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (request.isGeneralMatching) {
      return _GeneralMatchingWaitingBody(
        request: request,
        applicants: applicants,
        selectingWorkerId: selectingWorkerId,
        onSelectApplicant: onSelectApplicant,
      );
    }

    final radiusMeters = request.currentRadiusM.round();
    final radiusLabel = radiusMeters >= 1000
        ? '${(radiusMeters / 1000).toStringAsFixed(radiusMeters % 1000 == 0 ? 0 : 1)}km'
        : '${radiusMeters}m';
    final atMaxStage =
        request.currentStage >= TtmMatchingConstants.matchingStageCount;
    final countdownLabel = request.isOpen
        ? (atMaxStage
              ? '최대 범위 · $secondsToNext초'
              : '$secondsToNext초 후에 더 넓게 찾아봐요')
        : '진행 완료';
    final headline = atMaxStage
        ? '최대 범위 $radiusLabel 에서\n마지막으로 찾고 있어요'
        : '주변 $radiusLabel 까지\n알리고 있어요';
    final subline = atMaxStage
        ? '조금 더 기다려도 수락자가 없으면\n매칭이 종료돼요.'
        : '수락한 사람이 생기면 바로 알려드릴게요.';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? colors.surface : TtmColors.lightBackground;
    final pulseSize = (MediaQuery.sizeOf(context).shortestSide * 0.56).clamp(
      168.0,
      232.0,
    );

    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.xl,
          TtmSpacing.lg,
          TtmSpacing.xl,
          TtmSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TtmTierCard(
              tier: TtmCardTier.status,
              padding: const EdgeInsets.all(TtmSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StageProgressBar(currentStage: request.currentStage),
                  const SizedBox(height: TtmSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '단계 ${request.currentStage}/10',
                          style: TtmTypography.eyebrow.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: TtmSpacing.sm),
                      Flexible(
                        child: Text(
                          countdownLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TtmTypography.metric.copyWith(
                            fontSize: 13,
                            color: TtmSemanticColors.of(context).brandTeal,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: TtmSpacing.xl),
            Center(child: RadiusPulse(size: pulseSize)),
            const SizedBox(height: TtmSpacing.xl),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: TtmTypography.display.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: TtmSpacing.md),
            Text(
              subline,
              textAlign: TextAlign.center,
              style: TtmTypography.body.copyWith(
                fontSize: 15,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TtmSpacing.xl),
            TTMButton(
              label: '요청 취소',
              variant: TtmButtonVariant.ghost,
              busy: cancelling,
              onPressed: cancelling ? null : onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// 매칭 성공 — 짧은 스케일 + 체크 (티어 B).
class _GeneralMatchingWaitingBody extends StatelessWidget {
  const _GeneralMatchingWaitingBody({
    required this.request,
    required this.applicants,
    required this.selectingWorkerId,
    required this.onSelectApplicant,
  });

  final MatchRequest request;
  final AsyncValue<List<GeneralRequestApplicant>> applicants;
  final String? selectingWorkerId;
  final ValueChanged<GeneralRequestApplicant> onSelectApplicant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? colors.surface
        : TtmColors.lightBackground;

    return ColoredBox(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.xl,
          TtmSpacing.lg,
          TtmSpacing.xl,
          TtmSpacing.xl,
        ),
        children: [
          TtmTierCard(
            tier: TtmCardTier.status,
            padding: const EdgeInsets.all(TtmSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '일반 매칭 게시 중',
                  style: TtmTypography.title.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: TtmSpacing.sm),
                Text(
                  '작업자가 지원하면 아래 목록에 표시됩니다. 앱을 자유롭게 사용하다가 원하는 작업자를 선택하세요.',
                  style: TtmTypography.body.copyWith(
                    fontSize: 14,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.lg),
          Text(
            '지원자',
            style: TtmTypography.title.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: TtmSpacing.sm),
          applicants.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: TtmSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              '지원자를 불러오지 못했어요.\n$e',
              style: TtmTypography.body.copyWith(color: colors.error),
            ),
            data: (items) {
              if (items.isEmpty) {
                return TtmTierCard(
                  tier: TtmCardTier.feed,
                  padding: const EdgeInsets.all(TtmSpacing.lg),
                  child: Text(
                    '아직 지원한 작업자가 없어요.',
                    textAlign: TextAlign.center,
                    style: TtmTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final applicant in items) ...[
                    _ApplicantCard(
                      applicant: applicant,
                      busy: selectingWorkerId == applicant.workerId,
                      onSelect: () => onSelectApplicant(applicant),
                    ),
                    const SizedBox(height: TtmSpacing.sm),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: TtmSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.home),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('홈으로'),
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    '${AppRoutes.requestRoot}/${request.id}/edit',
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('게시글 수정'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.applicant,
    required this.busy,
    required this.onSelect,
  });

  final GeneralRequestApplicant applicant;
  final bool busy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rating = applicant.workerRating == null
        ? '평점 없음'
        : '${applicant.workerRating!.toStringAsFixed(1)}점';
    final trust = applicant.workerTrustScore == null
        ? null
        : '신뢰 ${applicant.workerTrustScore}';
    final formatter = NumberFormat.decimalPattern('ko');
    final rewardLabel = applicant.proposedReward == null
        ? '금액 제안 없음'
        : '${formatter.format(applicant.proposedReward)}원';
    final agreementLabel = applicant.agreementReady
        ? '양측 동의 완료'
        : applicant.proposedReward == null
        ? '협의 필요'
        : '요청자 ${applicant.requesterAcceptedAt == null ? '미동의' : '동의'} · 작업자 ${applicant.workerAcceptedAt == null ? '미동의' : '동의'}';
    return TtmTierCard(
      tier: TtmCardTier.feed,
      padding: const EdgeInsets.all(TtmSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  applicant.workerNickname?.isNotEmpty == true
                      ? applicant.workerNickname!
                      : '작업자',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TtmTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              Text(
                [rating, ?trust].join(' · '),
                style: TtmTypography.label.copyWith(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (applicant.initialMessage?.trim().isNotEmpty == true) ...[
            const SizedBox(height: TtmSpacing.sm),
            Text(
              applicant.initialMessage!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TtmTypography.body.copyWith(
                fontSize: 14,
                height: 1.35,
                color: colors.onSurface,
              ),
            ),
          ],
          const SizedBox(height: TtmSpacing.sm),
          Container(
            padding: const EdgeInsets.all(TtmSpacing.sm),
            decoration: BoxDecoration(
              color: applicant.agreementReady
                  ? colors.primary.withValues(alpha: 0.10)
                  : colors.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  applicant.agreementReady
                      ? Icons.verified_rounded
                      : Icons.handshake_outlined,
                  size: 18,
                  color: applicant.agreementReady
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: TtmSpacing.xs),
                Expanded(
                  child: Text(
                    '$rewardLabel · $agreementLabel',
                    style: TtmTypography.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: applicant.agreementReady
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '${AppRoutes.requestRoot}/${applicant.requestId}/applications/${applicant.applicationId}/chat',
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('채팅'),
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: busy || !applicant.agreementReady
                        ? null
                        : onSelect,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('선택'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchedDialog extends StatefulWidget {
  const _MatchedDialog({required this.isRequester});

  final bool isRequester;

  @override
  State<_MatchedDialog> createState() => _MatchedDialogState();
}

class _MatchedDialogState extends State<_MatchedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtl = AnimationController(vsync: this, duration: TtmMotion.slow);
    _scale = CurvedAnimation(parent: _scaleCtl, curve: TtmMotion.emphasized);
    _scaleCtl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _scaleCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? TtmColors.primaryDark : TtmColors.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.xl,
          TtmSpacing.lg,
          TtmSpacing.xl,
          TtmSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(TtmRadius.card),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: TtmSpacing.md),
            Text(
              '매칭 완료',
              style: TtmTypography.display.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: TtmSpacing.sm),
            MatchRoleBadge(isRequester: widget.isRequester),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              widget.isRequester
                  ? '요청자로 매칭됐어요.\n작업자와 진행 화면에서 만나요.'
                  : '작업자로 매칭됐어요.\n요청자와 진행 화면에서 만나요.',
              textAlign: TextAlign.center,
              style: TtmTypography.body.copyWith(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
