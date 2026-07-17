import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/concurrent_limit_messages.dart';
import '../../../core/utils/restriction_error_message.dart';
import '../../../core/utils/settlement_payout.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/home_navigation_provider.dart';
import '../../../data/providers/worker_activity_providers.dart';
import '../../../features/match/models/match_request.dart';
import '../../../features/match/models/general_request_applicant.dart';
import '../../../features/match/providers/match_providers.dart';
import '../../../features/profile/widgets/profile_photo_change.dart';
import '../../../shared/widgets/ttm_feed_skeleton.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../../shared/widgets/ttm_worker_presence_hero.dart';
import '../../../shared/widgets/user_restriction_notice.dart';
import 'home_greeting_strip.dart';
import 'home_metrics_strip.dart';
import 'general_request_post_card.dart';
import 'live_mission_card.dart';
import 'ttm_dense_task_card.dart';

/// 수행자 홈 — 대시보드 IA (3차: 인사 → Tier1 → Tier2 → 피드).
class DashboardHomeBody extends ConsumerStatefulWidget {
  const DashboardHomeBody({super.key});

  @override
  ConsumerState<DashboardHomeBody> createState() => _DashboardHomeBodyState();
}

class _DashboardHomeBodyState extends ConsumerState<DashboardHomeBody> {
  final Set<String> _accepting = {};
  bool _shownRestrictionNotice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncFeed());
    });
  }

  Future<void> _syncFeed() async {
    if (ref.read(authUserIdProvider) == null) return;
    try {
      final repo = ref.read(matchingRepositoryProvider);
      await repo.syncMyWorkerNotifications();
      await repo.flushPushDelivery();
    } catch (_) {}
    ref.invalidate(myPendingNotificationsProvider);
    ref.invalidate(myGeneralApplicationsProvider);
  }

  Future<void> _accept(String requestId) async {
    if (_accepting.contains(requestId)) return;
    setState(() => _accepting.add(requestId));
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .acceptRequest(requestId);
      if (!mounted) return;
      if (res['ok'] == true) {
        await syncMatchedWorkerTracking(ref);
        if (!mounted) return;
        context.push('${AppRoutes.requestRoot}/$requestId/active');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_failMsg(res['reason']?.toString() ?? '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final restrictionMsg = restrictionErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restrictionMsg.isNotEmpty ? restrictionMsg : '수락 오류: $e',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting.remove(requestId));
    }
  }

  String _failMsg(String reason) {
    final premium = ref.read(myProfileProvider).valueOrNull?.isPremium ?? false;
    final concurrent = acceptConcurrentLimitMessage(reason, isPremium: premium);
    if (concurrent.isNotEmpty) return concurrent;

    return switch (reason) {
      'not_open' => '이미 다른 사람이 수락했어요.',
      'race_or_self_request' => '본인 요청이거나 이미 매칭됐어요.',
      'request_not_found' => '요청을 찾을 수 없어요.',
      _ => '수락하지 못했어요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myActiveRestrictionsProvider, (_, next) {
      final restrictions = next.valueOrNull ?? const [];
      if (_shownRestrictionNotice || restrictions.isEmpty || !mounted) return;
      _shownRestrictionNotice = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 계정에 운영 제재가 적용되어 있습니다. 홈의 안내를 확인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const fabClearance = 64.0;
    final listBottomPad = 72 + bottomInset + fabClearance;
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final presence = ref.watch(myWorkerPresenceProvider).valueOrNull;
    final presenceStatus = presence?['status']?.toString();
    final isOnline = presenceStatus == 'online' || presenceStatus == 'busy';
    final feed = ref.watch(myPendingNotificationsProvider);
    final appliedGeneral = ref.watch(myGeneralApplicationsProvider);
    final active = ref.watch(myActiveMatchedRequestsProvider);
    final myGeneralPosts = ref.watch(myOpenGeneralRequestsProvider);
    final completedWork = ref.watch(myCompletedWorkRequestsProvider);
    final isPremium = profile?.isPremium ?? false;
    final slotLimit = isPremium ? 3 : 1;
    final activeSlots = _combinedActiveSlots(
      active.valueOrNull ?? const <MatchRequest>[],
      myGeneralPosts.valueOrNull ?? const <MatchRequest>[],
      appliedGeneral.valueOrNull ?? const [],
    );
    final todayEarnings = _todayWorkerNetEarnings(
      completedWork.valueOrNull ?? const <MatchRequest>[],
      isPremiumWorker: isPremium,
    );
    final activeRequests = active.valueOrNull ?? const <MatchRequest>[];
    final activeApplications =
        appliedGeneral.valueOrNull
            ?.where((item) => item.isPending && item.request.isOpen)
            .take(5)
            .toList(growable: false) ??
        const <GeneralRequestApplicationSummary>[];
    final showActiveLoading =
        active.isLoading &&
        appliedGeneral.isLoading &&
        activeRequests.isEmpty &&
        activeApplications.isEmpty;

    return RefreshIndicator(
      color: semantic.missionAccent,
      onRefresh: _syncFeed,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          TtmSpacing.lg,
          top + TtmSpacing.sm,
          TtmSpacing.lg,
          listBottomPad,
        ),
        children: [
          _TopBar(
            avatarUrl: profile?.profileImageUrl,
            onBell: () => ref.read(homeTabIndexProvider.notifier).state = 2,
            onAvatar: () => ref.read(homeTabIndexProvider.notifier).state = 5,
          ),
          const SizedBox(height: TtmSpacing.md),
          HomeGreetingStrip(
            nickname: profile?.nickname ?? '',
            isPremium: isPremium,
            isOnline: isOnline,
            nearbyCount: feed.valueOrNull?.length,
          ),
          const SizedBox(height: TtmSpacing.md),
          const UserRestrictionNotice(),
          const SizedBox(height: TtmSpacing.md),
          if (showActiveLoading)
            const SizedBox.shrink()
          else if (activeRequests.isNotEmpty || activeApplications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: TtmSpacing.md),
              child: _ActiveMissionCarousel(
                requests: activeRequests,
                applications: activeApplications,
                currentUserId: ref.read(authUserIdProvider),
                onOpen: (requestId) =>
                    context.push('${AppRoutes.requestRoot}/$requestId/active'),
                onOpenApplicationChat: (item) => context.push(
                  '${AppRoutes.requestRoot}/${item.requestId}/applications/${item.applicationId}/chat',
                ),
              ),
            ),
          const TtmWorkerPresenceHero(),
          const SizedBox(height: TtmSpacing.md),
          HomeMetricsStrip(
            nearbyCount: feed.valueOrNull?.length ?? 0,
            todayEarnings: todayEarnings,
            rating: profile?.rating,
            ratingCount: profile?.ratingCount ?? 0,
            activeSlots: activeSlots,
            slotLimit: slotLimit,
          ),
          const SizedBox(height: TtmSpacing.md),
          _RequestCta(onTap: () => context.push(AppRoutes.requestCreate)),
          myGeneralPosts.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (posts) {
              if (posts.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: TtmSpacing.lg,
                      bottom: TtmSpacing.sm,
                    ),
                    child: Text(
                      '내 일반 매칭 게시글',
                      style: TtmTypography.title.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: semantic.brandTeal,
                      ),
                    ),
                  ),
                  for (final post in posts.take(3)) ...[
                    _MyGeneralPostRow(request: post),
                    const SizedBox(height: TtmSpacing.sm),
                  ],
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: TtmSpacing.lg,
              bottom: TtmSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  '주변 심부름',
                  style: TtmTypography.title.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: semantic.brandTeal,
                  ),
                ),
                const Spacer(),
                if (isOnline)
                  IconButton(
                    onPressed: () => unawaited(_syncFeed()),
                    tooltip: '목록 새로고침',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (!isOnline)
            const _NeighborhoodSignalCard(
              title: '주변 요청을 받을 준비를 해둘까요?',
              subtitle: '활동을 켜면 근처에 새 심부름이 올라올 때 바로 확인할 수 있어요.',
              statusLabel: '활동 OFF',
              icon: Icons.location_off_outlined,
              active: false,
            )
          else
            feed.when(
              loading: () => const TtmFeedSkeleton(),
              error: (_, _) => const Text('목록을 불러오지 못했어요.'),
              data: (list) {
                if (list.isEmpty) {
                  return const _NeighborhoodSignalCard(
                    title: '지금은 조용한 시간이에요',
                    subtitle: '활동은 켜져 있어요. 새 요청이 잡히면 이곳에 바로 뜹니다.',
                    statusLabel: '요청 감지 중',
                    icon: Icons.radar_rounded,
                    active: true,
                  );
                }

                final items = list.take(8).toList();
                const start = 0;
                if (start >= items.length) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: [
                    for (var i = start; i < items.length; i++) ...[
                      if (i > start) const SizedBox(height: TtmSpacing.sm),
                      TtmDenseTaskCard(
                        notification: items[i],
                        trailingClearance: fabClearance,
                        busy: _accepting.contains(items[i].requestId),
                        onAccept: () => _accept(items[i].requestId),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  int _combinedActiveSlots(
    List<MatchRequest> active,
    List<MatchRequest> generalPosts,
    List<GeneralRequestApplicationSummary> applications,
  ) {
    final keys = <String>{};
    for (final request in active) {
      keys.add('request:${request.id}');
    }
    for (final request in generalPosts.where((item) => item.isOpen)) {
      keys.add('request:${request.id}');
    }
    for (final application in applications.where((item) => item.isPending)) {
      keys.add('application:${application.applicationId}');
    }
    return keys.length;
  }

  int _todayWorkerNetEarnings(
    List<MatchRequest> requests, {
    required bool isPremiumWorker,
  }) {
    final now = DateTime.now();
    return requests
        .where((request) {
          final completed = request.completedAt?.toLocal();
          return completed != null &&
              completed.year == now.year &&
              completed.month == now.month &&
              completed.day == now.day;
        })
        .fold<int>(0, (sum, request) {
          final gross = (request.negotiatedReward ?? request.reward).round();
          return sum +
              workerNetAfterFee(gross, isPremiumWorker: isPremiumWorker);
        });
  }
}

class _NeighborhoodSignalCard extends StatefulWidget {
  const _NeighborhoodSignalCard({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.icon,
    required this.active,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final IconData icon;
  final bool active;

  @override
  State<_NeighborhoodSignalCard> createState() =>
      _NeighborhoodSignalCardState();
}

class _NeighborhoodSignalCardState extends State<_NeighborhoodSignalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final accent = widget.active ? semantic.missionAccent : semantic.brandTeal;

    return TtmTierCard(
      tier: widget.active ? TtmCardTier.mission : TtmCardTier.feed,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final dotScale = 0.9 + (_pulse.value * 0.18);
          final glow = 0.08 + (_pulse.value * 0.12);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.scale(
                scale: dotScale,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: glow),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: accent, size: 22),
                ),
              ),
              const SizedBox(width: TtmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _LiveStatusDot(active: widget.active, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          widget.statusLabel,
                          style: TtmTypography.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: widget.active
                                ? accent
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TtmSpacing.xs),
                    Text(
                      widget.title,
                      style: TtmTypography.title.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TtmTypography.body.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveStatusDot extends StatefulWidget {
  const _LiveStatusDot({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  State<_LiveStatusDot> createState() => _LiveStatusDotState();
}

class _LiveStatusDotState extends State<_LiveStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final alpha = widget.active ? 0.55 + (_ctl.value * 0.45) : 0.45;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: alpha),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _AppliedGeneralApplicationMissionCard extends StatelessWidget {
  const _AppliedGeneralApplicationMissionCard({
    required this.item,
    required this.onOpenChat,
  });

  static const _yellow = Color(0xFFF6C445);

  final GeneralRequestApplicationSummary item;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final reward = item.proposedReward ?? item.request.reward;
    final rewardFmt = NumberFormat.decimalPattern('ko').format(reward);
    final agreementLabel = item.agreementReady
        ? '양측 동의 완료'
        : item.proposedReward == null
        ? '금액 제안 필요'
        : '동의 대기';

    return TtmTierCard(
      tier: TtmCardTier.mission,
      borderColorOverride: _yellow,
      onTap: onOpenChat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_rounded,
                size: 18,
                color: _yellow,
              ),
              const SizedBox(width: TtmSpacing.sm),
              Text(
                '지원 중',
                style: TtmTypography.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _yellow,
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              _MissionPill(label: '일반 매칭', color: _yellow),
              const Spacer(),
              Text(
                '₩$rewardFmt',
                style: TtmTypography.moneyDisplay.copyWith(
                  fontSize: 30,
                  color: semantic.missionAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.md),
          Text(
            item.request.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TtmTypography.title.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: TtmSpacing.xs),
          Text(
            agreementLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TtmTypography.body.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onOpenChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('지원 채팅'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionPill extends StatelessWidget {
  const _MissionPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TtmTypography.label.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ActiveMissionCarousel extends StatefulWidget {
  const _ActiveMissionCarousel({
    required this.requests,
    required this.applications,
    required this.currentUserId,
    required this.onOpen,
    required this.onOpenApplicationChat,
  });

  final List<MatchRequest> requests;
  final List<GeneralRequestApplicationSummary> applications;
  final String? currentUserId;
  final ValueChanged<String> onOpen;
  final ValueChanged<GeneralRequestApplicationSummary> onOpenApplicationChat;

  @override
  State<_ActiveMissionCarousel> createState() => _ActiveMissionCarouselState();
}

class _ActiveMissionCarouselState extends State<_ActiveMissionCarousel> {
  static const _interval = Duration(seconds: 10);
  static const _transitionDuration = Duration(milliseconds: 900);

  Timer? _timer;
  late final PageController _pageController;
  int _index = 0;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _ActiveMissionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncTimer() {
    final count = widget.requests.length + widget.applications.length;
    if (_lastCount != count) {
      _index = 0;
      _lastCount = count;
      _timer?.cancel();
      _timer = null;
    }

    if (count <= 1) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _timer ??= Timer.periodic(_interval, (_) {
      if (!mounted) return;
      final next = (_index + 1) % count;
      _pageController.animateToPage(
        next,
        duration: _transitionDuration,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.requests.length + widget.applications.length;
    if (count == 0) return const SizedBox.shrink();
    if (_index >= count) _index = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: count,
            onPageChanged: (value) {
              setState(() => _index = value);
            },
            itemBuilder: (context, i) {
              final request = i < widget.requests.length
                  ? widget.requests[i]
                  : null;
              final application = request == null
                  ? widget.applications[i - widget.requests.length]
                  : null;
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  var page = _index.toDouble();
                  if (_pageController.hasClients &&
                      _pageController.position.haveDimensions) {
                    page = _pageController.page ?? page;
                  }
                  final distance = (page - i).abs().clamp(0.0, 1.0);
                  final opacity = 1.0 - (distance * 0.22);
                  final offset = Offset((i - page) * 0.035, 0);

                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(
                        offset.dx * MediaQuery.sizeOf(context).width,
                        0,
                      ),
                      child: child,
                    ),
                  );
                },
                child: request != null
                    ? LiveMissionCard.active(
                        request: request,
                        currentUserId: widget.currentUserId,
                        onOpen: () => widget.onOpen(request.id),
                      )
                    : _AppliedGeneralApplicationMissionCard(
                        item: application!,
                        onOpenChat: () =>
                            widget.onOpenApplicationChat(application),
                      ),
              );
            },
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: TtmSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: i == _index ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: i == _index ? 0.9 : 0.28,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.avatarUrl,
    required this.onBell,
    required this.onAvatar,
  });

  final String? avatarUrl;
  final VoidCallback onBell;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        SvgPicture.asset('assets/images/ttm_symbol.svg', width: 26, height: 26),
        const SizedBox(width: 7),
        Text(
          '틈틈',
          style: TtmTypography.title.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colors.primary,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onBell,
          icon: SvgPicture.asset(
            'assets/icons/bell.svg',
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              colors.onSurfaceVariant,
              BlendMode.srcIn,
            ),
          ),
        ),
        GestureDetector(
          onTap: onAvatar,
          child: TtmProfileAvatar(imageUrl: avatarUrl, size: 32),
        ),
      ],
    );
  }
}

class _RequestCta extends StatelessWidget {
  const _RequestCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TtmSpacing.lg,
          vertical: TtmSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: TtmColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TtmColors.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: TtmColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: TtmColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: TtmSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '심부름 맡기기',
                    style: TtmTypography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TtmColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '만남 위치와 보상을 정해 주변에 알려요',
                    style: TtmTypography.body.copyWith(
                      fontSize: 14,
                      color: TtmColors.deepGreen.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TtmSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: TtmColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _MyGeneralPostRow extends StatelessWidget {
  const _MyGeneralPostRow({required this.request});

  final MatchRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('${AppRoutes.requestRoot}/${request.id}/general'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TtmSpacing.md,
            vertical: TtmSpacing.sm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GeneralRequestThumbnail(
                  imageUrl: request.thumbnailUrl,
                  size: 52,
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TtmTypography.title.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '지원 ${request.applicationCount}',
                          style: TtmTypography.body.copyWith(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: TtmSpacing.sm),
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '댓글 ${request.commentCount}',
                          style: TtmTypography.body.copyWith(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TtmTypography.body.copyWith(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              Text(
                request.rewardLabel(),
                style: TtmTypography.moneyDisplay.copyWith(
                  fontSize: 14,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: TtmSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
