import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../models/exercise_matching_models.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';
import '../services/exercise_location_service.dart';
import '../widgets/raid_live_map.dart';

class RaidDetailScreen extends ConsumerStatefulWidget {
  const RaidDetailScreen({super.key, required this.raidId});
  final String raidId;

  @override
  ConsumerState<RaidDetailScreen> createState() => _RaidDetailScreenState();
}

class _RaidDetailScreenState extends ConsumerState<RaidDetailScreen> {
  bool _busy = false;
  Timer? _refreshTimer;
  Timer? _locationTimer;
  Raid? _visibleRaid;
  bool _locationUpdateBusy = false;
  DateTime? _lastLocationUpdateAt;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_busy) {
        ref.invalidate(raidDetailProvider(widget.raidId));
      }
    });
    _locationTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_updateMyRaidLocation());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(raidDetailProvider(widget.raidId));
    return Scaffold(
      appBar: AppBar(title: const Text('레이드 상세')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('레이드 정보를 불러오지 못했어요.')),
        data: _body,
      ),
    );
  }

  Widget _body(RaidDetail detail) {
    final raid = detail.raid;
    _visibleRaid = raid;
    if (_canShareLocation(raid) &&
        (_lastLocationUpdateAt == null ||
            DateTime.now().difference(_lastLocationUpdateAt!).inSeconds > 10)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_updateMyRaidLocation());
      });
    }
    final uid = ref.watch(authUserIdProvider);
    final isOrganizer = raid.organizerId == uid;
    final recruitment = isOrganizer
        ? ref.watch(raidRecruitmentProvider(raid.id))
        : null;
    final approved = detail.participants
        .where((item) => item.isApproved)
        .toList();
    final applicants = detail.participants
        .where(
          (item) => item.status == 'applied' || item.status == 'waitlisted',
        )
        .toList();
    final liveLocations =
        ref.watch(raidLocationsProvider(raid.id)).valueOrNull ??
        const <RaidLiveLocation>[];
    final approvedUserIds = approved.map((item) => item.userId).toSet();
    final visibleLocations = liveLocations
        .where((location) => approvedUserIds.contains(location.userId))
        .toList(growable: false);
    final date = DateFormat(
      'yyyy년 M월 d일 (E) HH:mm',
      'ko',
    ).format(raid.startsAt);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.lg,
          TtmSpacing.md,
          TtmSpacing.lg,
          48,
        ),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: TtmColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  color: TtmColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: TtmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raid.title,
                      style: TtmTypography.display.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${exerciseLabel(raid.exerciseType)} · ${raidStatusLabel(raid.status)}',
                      style: TtmTypography.label.copyWith(
                        color: TtmColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.lg),
          TtmTierCard(
            tier: TtmCardTier.feed,
            padding: const EdgeInsets.all(TtmSpacing.md),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.place_outlined,
                  title: raid.venue.name,
                  subtitle: raid.venue.address,
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.event_outlined,
                  title: date,
                  subtitle: '${raid.durationMinutes}분 동안 진행',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.people_alt_outlined,
                  title: '${raid.participantCount}/${raid.maxParticipants}명 참가',
                  subtitle: '최소 ${raid.minParticipants}명이 모이면 확정',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.speed_outlined,
                  title: '강도 ${intensityLabel(raid.intensity)}',
                  subtitle: raid.beginnerFriendly
                      ? '초보자도 참가할 수 있어요'
                      : '운동 경험이 필요해요',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  title: raid.isFree
                      ? '참가비 없음'
                      : '${NumberFormat.decimalPattern('ko').format(raid.participationFee)}원',
                  subtitle: raid.isFree
                      ? '누구나 가볍게 참가할 수 있어요'
                      : '승인 후 참가비가 보관돼요',
                ),
              ],
            ),
          ),
          if (_canShareLocation(raid)) ...[
            const SizedBox(height: TtmSpacing.lg),
            Text(
              '집합 장소와 참가자 위치',
              style: TtmTypography.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: TtmSpacing.sm),
            RaidLiveMap(
              meetingLatitude: raid.venue.latitude,
              meetingLongitude: raid.venue.longitude,
              meetingLabel: raid.venue.name,
              locations: visibleLocations,
              participants: approved,
              myUserId: uid,
            ),
            const SizedBox(height: TtmSpacing.xs),
            Text(
              '승인된 참가자에게만 최근 위치가 표시돼요. 위치는 이 화면을 보는 동안 갱신됩니다.',
              style: TtmTypography.label.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (raid.description.trim().isNotEmpty) ...[
            const SizedBox(height: TtmSpacing.lg),
            Text('레이드 안내', style: TtmTypography.title.copyWith(fontSize: 18)),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              raid.description,
              style: TtmTypography.body.copyWith(height: 1.6),
            ),
          ],
          if (raid.myParticipant != null) ...[
            const SizedBox(height: TtmSpacing.lg),
            _MyStatus(participant: raid.myParticipant!),
          ],
          if (raid.isApplied && raid.myParticipant != null) ...[
            const SizedBox(height: TtmSpacing.md),
            TTMButton(
              label: '운영자와 1:1 채팅',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: () => context.push(
                '${AppRoutes.raidRoot}/${raid.id}/applications/'
                '${raid.myParticipant!.id}/chat',
              ),
            ),
          ],
          if (raid.isMember) ...[
            const SizedBox(height: TtmSpacing.md),
            TTMButton(
              label: raid.status == 'completed' || raid.status == 'cancelled'
                  ? '레이드 단체채팅 기록 보기'
                  : '레이드 단체채팅',
              icon: Icons.forum_outlined,
              onPressed: () =>
                  context.push('${AppRoutes.raidRoot}/${raid.id}/chat'),
            ),
          ],
          if (isOrganizer && applicants.isNotEmpty) ...[
            const SizedBox(height: TtmSpacing.xl),
            Text(
              '참가 신청 ${applicants.length}',
              style: TtmTypography.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: TtmSpacing.sm),
            for (final applicant in applicants) ...[
              _ApplicantCard(
                participant: applicant,
                busy: _busy,
                onChat: () => context.push(
                  '${AppRoutes.raidRoot}/${raid.id}/applications/'
                  '${applicant.id}/chat',
                ),
                onDecision: (decision) => _review(applicant.id, decision),
              ),
              const SizedBox(height: TtmSpacing.sm),
            ],
          ],
          if (isOrganizer && raid.isJoinable) ...[
            const SizedBox(height: TtmSpacing.lg),
            recruitment!.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => _RecruitmentPanel(
                campaign: null,
                busy: _busy,
                onStart: () => _startRecruitment(raid),
              ),
              data: (campaign) => _RecruitmentPanel(
                campaign: campaign,
                busy: _busy,
                onStart: () => _startRecruitment(raid),
              ),
            ),
          ],
          if (approved.isNotEmpty && (isOrganizer || raid.isMember)) ...[
            const SizedBox(height: TtmSpacing.xl),
            Text(
              '참가자 ${approved.length}',
              style: TtmTypography.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: TtmSpacing.sm),
            for (final participant in approved) ...[
              _ParticipantTile(
                participant: participant,
                showAttendanceControls:
                    isOrganizer &&
                    raid.source == 'premium' &&
                    !participant.isOrganizer &&
                    raid.startsAt.isBefore(DateTime.now()),
                showVoteControls:
                    raid.source == 'auto' &&
                    uid != participant.userId &&
                    raid.endsAt.isBefore(DateTime.now()) &&
                    participant.attendanceStatus == 'pending',
                onAttendance: (status) => _attendance(participant.id, status),
                onVote: (vote) => _vote(participant.id, vote),
              ),
              const Divider(height: 1),
            ],
          ],
          const SizedBox(height: TtmSpacing.xl),
          if (raid.isJoinable && raid.myParticipant == null)
            TTMButton(
              label: raid.isFree ? '바로 참가하기' : '참가 신청하기',
              busy: _busy,
              onPressed: _busy ? null : () => _join(raid),
              icon: Icons.directions_run_rounded,
            ),
          if (!isOrganizer &&
              raid.myParticipant != null &&
              !{'cancelled', 'rejected'}.contains(raid.myParticipant!.status) &&
              raid.startsAt.isAfter(DateTime.now()))
            TTMButton(
              label: '참가 취소',
              variant: TtmButtonVariant.ghost,
              busy: _busy,
              onPressed: _busy ? null : () => _leave(raid.id),
            ),
          if (isOrganizer &&
              raid.isPremiumRaid &&
              raid.endsAt.isBefore(DateTime.now()) &&
              !{'completed', 'cancelled'}.contains(raid.status)) ...[
            TTMButton(
              label: '레이드 완료',
              busy: _busy,
              onPressed: _busy ? null : () => _confirmFinalize(raid),
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: TtmSpacing.sm),
          ],
          if (isOrganizer && !{'completed', 'cancelled'}.contains(raid.status))
            TTMButton(
              label: '레이드 취소',
              variant: TtmButtonVariant.danger,
              busy: _busy,
              onPressed: _busy ? null : () => _cancel(raid.id),
            ),
        ],
      ),
    );
  }

  Future<void> _join(Raid raid) async {
    String? message;
    if (!raid.isFree) {
      message = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('참가 신청'),
            content: TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '운영자에게 전할 내용을 적어주세요.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('신청'),
              ),
            ],
          );
        },
      );
      if (message == null) return;
    }
    await _run(() async {
      try {
        final location = await ref
            .read(exerciseLocationServiceProvider)
            .current();
        return raid.isFree
            ? ref.read(raidRepositoryProvider).joinFree(raid.id, location)
            : ref
                  .read(raidRepositoryProvider)
                  .applyPremium(raid.id, location, message: message);
      } on ExerciseLocationException catch (error) {
        return {'ok': false, 'reason': error.reason};
      }
    }, success: raid.isFree ? '참가가 확정됐어요.' : '참가 신청을 보냈어요.');
  }

  Future<void> _startRecruitment(Raid raid) async {
    var fillGoal = 'minimum';
    var approvalMode = 'manual';
    final options = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(TtmSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '긴급 참가자 모집',
                  style: TtmTypography.display.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  '대기자부터 알리고, 1km · 3km · 5km 순서로 범위를 넓혀요.',
                  style: TtmTypography.body,
                ),
                const SizedBox(height: TtmSpacing.lg),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'minimum', label: Text('최소 인원까지')),
                    ButtonSegment(value: 'maximum', label: Text('최대 인원까지')),
                  ],
                  selected: {fillGoal},
                  onSelectionChanged: (value) =>
                      setSheetState(() => fillGoal = value.first),
                  showSelectedIcon: false,
                ),
                if (!raid.isFree) ...[
                  const SizedBox(height: TtmSpacing.md),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'manual', label: Text('직접 승인')),
                      ButtonSegment(value: 'instant', label: Text('즉시 승인')),
                    ],
                    selected: {approvalMode},
                    onSelectionChanged: (value) =>
                        setSheetState(() => approvalMode = value.first),
                    showSelectedIcon: false,
                  ),
                ],
                const SizedBox(height: TtmSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'fill_goal': fillGoal,
                    'approval_mode': raid.isFree ? 'instant' : approvalMode,
                  }),
                  child: const Text('긴급 모집 시작'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (options == null) return;
    await _run(
      () => ref
          .read(raidRepositoryProvider)
          .startRaidRecruitment(
            raidId: raid.id,
            fillGoal: options['fill_goal']!,
            approvalMode: options['approval_mode']!,
          ),
      success: '긴급 모집을 시작했어요.',
    );
    ref.invalidate(raidRecruitmentProvider(raid.id));
  }

  Future<void> _review(String participantId, String decision) => _run(
    () => ref
        .read(raidRepositoryProvider)
        .reviewApplication(participantId, decision),
    success: switch (decision) {
      'approved' => '참가를 승인했어요.',
      'waitlisted' => '대기 상태로 변경했어요.',
      _ => '참가 신청을 거절했어요.',
    },
  );

  Future<void> _leave(String raidId) => _run(
    () => ref.read(raidRepositoryProvider).leave(raidId),
    success: '참가를 취소했어요.',
  );
  Future<void> _attendance(String id, String status) => _run(
    () => ref.read(raidRepositoryProvider).recordAttendance(id, status),
    success: '출석 상태를 저장했어요.',
  );
  Future<void> _vote(String id, String vote) => _run(
    () => ref.read(raidRepositoryProvider).castAttendanceVote(id, vote),
    success: '출석 확인 의견을 보냈어요.',
  );
  Future<void> _confirmFinalize(Raid raid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('레이드를 완료할까요?'),
        content: const Text(
          '참석·지각·중도 이탈 참가자는 완료 보너스 100P를 받고, '
          '불참 참가자는 보유 포인트에서 최대 100P가 차감돼요. '
          '모든 참가자의 출석 상태를 확인한 뒤 완료해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('완료하기'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _finalize(raid.id);
  }

  Future<void> _finalize(String raidId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(raidRepositoryProvider).finalize(raidId);
      if (!mounted) return;
      if (result['ok'] == true) {
        final bonus = (result['participant_bonus_total'] as num?)?.toInt() ?? 0;
        final penalty = (result['absence_penalty_total'] as num?)?.toInt() ?? 0;
        _show('레이드가 완료됐어요. 참여 보너스 ${bonus}P · 불참 감점 ${penalty}P');
        await _reload();
      } else {
        _show(_reason(result['reason']?.toString()));
      }
    } catch (error) {
      if (mounted) _show(_reason(error.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _canShareLocation(Raid raid) =>
      raid.isMember && !{'completed', 'cancelled'}.contains(raid.status);

  Future<void> _updateMyRaidLocation() async {
    final raid = _visibleRaid;
    if (raid == null || !_canShareLocation(raid) || _locationUpdateBusy) return;
    _locationUpdateBusy = true;
    try {
      final location = await ref
          .read(exerciseLocationServiceProvider)
          .current(request: false);
      final result = await ref
          .read(raidRepositoryProvider)
          .updateRaidLocation(raidId: raid.id, location: location);
      if (result['ok'] == true) _lastLocationUpdateAt = DateTime.now();
    } catch (_) {
      // The meeting marker remains available when location permission is off.
    } finally {
      _locationUpdateBusy = false;
    }
  }

  Future<void> _cancel(String raidId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('레이드를 취소할까요?'),
        content: const Text('보관 중인 참가비는 모두 반환됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(
        () => ref.read(raidRepositoryProvider).cancel(raidId, '운영자 취소'),
        success: '레이드를 취소했어요.',
      );
    }
  }

  Future<void> _run(
    Future<Map<String, dynamic>> Function() action, {
    required String success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      _show(
        result['ok'] == true ? success : _reason(result['reason']?.toString()),
      );
      if (result['ok'] == true) await _reload();
    } catch (error) {
      if (mounted) _show(_reason(error.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    ref.invalidate(raidDetailProvider(widget.raidId));
    ref.invalidate(nearbyRaidsProvider);
    ref.invalidate(raidBrowseProvider);
    ref.invalidate(myRaidsProvider);
    ref.invalidate(rewardSummaryProvider);
    ref.invalidate(raidFeeWalletProvider);
    await ref.read(raidDetailProvider(widget.raidId).future);
  }

  String _reason(String? reason) {
    final value = reason ?? '';
    const locationReasons = {
      'location_service_disabled',
      'location_permission_denied',
      'location_permission_forever',
      'inaccurate_location',
      'stale_location',
      'outside_raid_range',
      'schedule_conflict',
    };
    for (final item in locationReasons) {
      if (value.contains(item)) return exerciseLocationMessage(item);
    }
    if (value.contains('raid_full')) return '참가 정원이 모두 찼어요.';
    if (value.contains('insufficient_balance')) return '참가비 지갑 잔액이 부족해요.';
    if (value.contains('already')) return '이미 처리된 참가 상태예요.';
    if (value.contains('attendance_pending')) {
      return '모든 참가자의 출석 상태를 먼저 확인해 주세요.';
    }
    if (value.contains('already_completed')) return '이미 완료된 레이드예요.';
    if (value.contains('raid_not_finished')) return '레이드가 끝난 뒤 처리할 수 있어요.';
    return '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.';
  }

  void _show(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

class _RecruitmentPanel extends StatelessWidget {
  const _RecruitmentPanel({
    required this.campaign,
    required this.busy,
    required this.onStart,
  });

  final RaidRecruitmentCampaign? campaign;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final value = campaign;
    final active = value != null && value.status == 'recruiting';
    return TtmTierCard(
      tier: TtmCardTier.status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: TtmColors.primary),
              const SizedBox(width: TtmSpacing.sm),
              Expanded(child: Text('긴급 참가자 모집', style: TtmTypography.title)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            active
                ? '${value.targetParticipants}명까지 모집 중 · ${value.offerCount}명에게 알림 전송'
                : '인원이 부족할 때 가까운 사용자에게 단계적으로 알려요.',
            style: TtmTypography.body,
          ),
          const SizedBox(height: TtmSpacing.sm),
          if (active)
            LinearProgressIndicator(value: value.currentStage / 3)
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onStart,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('긴급 모집 설정'),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: TtmColors.primary),
      const SizedBox(width: TtmSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TtmTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TtmTypography.label.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MyStatus extends StatelessWidget {
  const _MyStatus({required this.participant});
  final RaidParticipant participant;
  @override
  Widget build(BuildContext context) => TtmTierCard(
    tier: TtmCardTier.status,
    child: Row(
      children: [
        const Icon(Icons.verified_outlined, color: TtmColors.primary),
        const SizedBox(width: TtmSpacing.sm),
        Expanded(
          child: Text(switch (participant.status) {
            'approved' => '참가가 확정됐어요',
            'applied' => '운영자가 참가 신청을 확인하고 있어요',
            'waitlisted' => '참가 대기 중이에요',
            'rejected' => '이번 레이드에는 참가하기 어려워요',
            'cancelled' => '참가를 취소했어요',
            _ => participant.status,
          }, style: TtmTypography.body.copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.participant,
    required this.busy,
    required this.onChat,
    required this.onDecision,
  });
  final RaidParticipant participant;
  final bool busy;
  final VoidCallback onChat;
  final ValueChanged<String> onDecision;
  @override
  Widget build(BuildContext context) => TtmTierCard(
    tier: TtmCardTier.feed,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(participant.nickname ?? '참가 신청자', style: TtmTypography.title),
        if (participant.applicationMessage?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(participant.applicationMessage!),
        ],
        const SizedBox(height: TtmSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('지원자와 1:1 채팅'),
          ),
        ),
        const SizedBox(height: TtmSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => onDecision('rejected'),
                child: const Text('거절'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => onDecision('waitlisted'),
                child: const Text('대기'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : () => onDecision('approved'),
                child: const Text('승인'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.showAttendanceControls,
    required this.showVoteControls,
    required this.onAttendance,
    required this.onVote,
  });
  final RaidParticipant participant;
  final bool showAttendanceControls;
  final bool showVoteControls;
  final ValueChanged<String> onAttendance;
  final ValueChanged<String> onVote;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TtmSpacing.sm),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundImage: participant.profileImageUrl == null
                  ? null
                  : NetworkImage(participant.profileImageUrl!),
              child: participant.profileImageUrl == null
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            const SizedBox(width: TtmSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.nickname ?? '참가자',
                    style: TtmTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    participant.isOrganizer
                        ? '운영자'
                        : _attendanceLabel(participant.attendanceStatus),
                    style: TtmTypography.label,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showAttendanceControls)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 5,
              children: [
                ActionChip(
                  label: const Text('참석'),
                  onPressed: () => onAttendance('present'),
                ),
                ActionChip(
                  label: const Text('지각'),
                  onPressed: () => onAttendance('late'),
                ),
                ActionChip(
                  label: const Text('중도 이탈'),
                  onPressed: () => onAttendance('left_early'),
                ),
                ActionChip(
                  label: const Text('불참'),
                  onPressed: () => onAttendance('absent'),
                ),
              ],
            ),
          ),
        if (showVoteControls)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 5,
              children: [
                ActionChip(
                  label: const Text('참여 확인'),
                  onPressed: () => onVote('present'),
                ),
                ActionChip(
                  label: const Text('확인 불가'),
                  onPressed: () => onVote('cannot_confirm'),
                ),
                ActionChip(
                  label: const Text('미참여'),
                  onPressed: () => onVote('absent'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

String _attendanceLabel(String status) => switch (status) {
  'present' => '참석 완료',
  'late' => '지각',
  'left_early' => '중도 이탈',
  'absent' => '불참',
  'disputed' => '출석 확인 중',
  'exempt' => '운영자',
  _ => '출석 확인 전',
};
