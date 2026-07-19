import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../core/utils/settlement_payout.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../features/match/providers/match_providers.dart';
import '../../../features/match/models/match_request.dart';
import '../../../shared/widgets/ttm_empty_state.dart';
import '../../../shared/widgets/ttm_section_header.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../../shared/widgets/user_restriction_notice.dart';
import 'general_request_post_card.dart';
import 'live_mission_card.dart';

/// 활동 탭 — 진행 중 심부름 + 수익 + 도운/맡긴 심부름 내역.
class ActivityTabBody extends ConsumerStatefulWidget {
  const ActivityTabBody({super.key});

  @override
  ConsumerState<ActivityTabBody> createState() => _ActivityTabBodyState();
}

class _ActivityTabBodyState extends ConsumerState<ActivityTabBody>
    with SingleTickerProviderStateMixin {
  late final TabController _historyTab;

  @override
  void initState() {
    super.initState();
    _historyTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _historyTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final active = ref.watch(myActiveMatchedRequestsProvider);
    final generalPosts = ref.watch(myOpenGeneralRequestsProvider);
    final uid = ref.watch(authUserIdProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isPremium = profile?.isPremium ?? false;
    final completedWork = ref.watch(myCompletedWorkRequestsProvider);
    final completedRequested = ref.watch(myCompletedRequestedRequestsProvider);
    final workList = completedWork.valueOrNull ?? const <MatchRequest>[];
    final todayGross = workList
        .where((r) {
          final completed = r.completedAt?.toLocal();
          final now = DateTime.now();
          return completed != null &&
              completed.year == now.year &&
              completed.month == now.month &&
              completed.day == now.day;
        })
        .fold<int>(0, (sum, r) => sum + _workerNet(r, isPremium));
    final weeklyGross = workList
        .where((r) {
          final completed = r.completedAt;
          return completed != null &&
              completed.isAfter(
                DateTime.now().subtract(const Duration(days: 7)),
              );
        })
        .fold<int>(0, (sum, r) => sum + _workerNet(r, isPremium));
    final money = NumberFormat.decimalPattern('ko');

    return ListView(
      padding: EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        TtmSpacing.lg,
        TtmSpacing.lg,
        80 + bottom,
      ),
      children: [
        const UserRestrictionNotice(compact: true),
        const SizedBox(height: TtmSpacing.lg),
        generalPosts.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TtmSectionHeader(title: '내 일반 매칭 게시글'),
                for (final post in list.take(3)) ...[
                  _GeneralPostTile(request: post),
                  const SizedBox(height: TtmSpacing.sm),
                ],
                const SizedBox(height: TtmSpacing.lg),
              ],
            );
          },
        ),
        // ── 진행 중인 심부름 ─────────────────────────────────
        active.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: TtmSpacing.xl),
                child: _ActivityWaitingCard(),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TtmSectionHeader(title: '진행 중인 ○○'),
                LiveMissionCard.active(
                  request: list.first,
                  currentUserId: uid,
                  onOpen: () => context.push(
                    '${AppRoutes.requestRoot}/${list.first.id}/active',
                  ),
                ),
                const SizedBox(height: TtmSpacing.xl),
              ],
            );
          },
        ),

        // ── 수익 ────────────────────────────────────────────
        const TtmSectionHeader(title: '수익'),
        TtmTierCard(
          tier: TtmCardTier.status,
          padding: const EdgeInsets.all(TtmSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '오늘 수익',
                    style: TtmTypography.title.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TtmSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: TtmColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '정산 전',
                      style: TtmTypography.label.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: TtmColors.deepGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TtmSpacing.sm),
              Text(
                '₩${money.format(todayGross)}',
                style: TtmTypography.moneyDisplay.copyWith(
                  fontSize: 40,
                  color: semantic.brandTeal,
                ),
              ),
              const SizedBox(height: TtmSpacing.xs),
              Text(
                '완료된 작업 기준 보상 합계예요.',
                style: TtmTypography.body.copyWith(
                  fontSize: 15,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TtmSpacing.md),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: TtmSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _EarningsStat(
                      label: '이번 주',
                      value: '₩${money.format(weeklyGross)}',
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      width: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  Expanded(
                    child: _EarningsStat(
                      label: '완료',
                      value: '${workList.length}건',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── 활동 기록 ────────────────────────────────────────
        const TtmSectionHeader(title: '활동 기록'),
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          child: TabBar(
            controller: _historyTab,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: colors.outlineVariant.withValues(alpha: 0.35),
            labelStyle: TtmTypography.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TtmTypography.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: '도운 ○○'),
              Tab(text: '맡긴 ○○'),
            ],
          ),
        ),
        const SizedBox(height: TtmSpacing.sm),
        SizedBox(
          height: 260,
          child: TabBarView(
            controller: _historyTab,
            children: [
              _HistoryList(
                async: completedWork,
                emptyTitle: '아직 도운 내역이 없어요',
                emptySubtitle: '완료한 작업이 여기에 쌓여요',
                onOpen: (id) =>
                    context.push('${AppRoutes.requestRoot}/$id/active'),
              ),
              _HistoryList(
                async: completedRequested,
                emptyTitle: '아직 맡긴 내역이 없어요',
                emptySubtitle: '완료된 요청이 여기에 쌓여요',
                onOpen: (id) =>
                    context.push('${AppRoutes.requestRoot}/$id/active'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _workerNet(MatchRequest request, bool isPremiumWorker) {
    final gross = (request.negotiatedReward ?? request.reward).round();
    return workerNetAfterFee(gross, isPremiumWorker: isPremiumWorker);
  }
}

class _GeneralPostTile extends StatelessWidget {
  const _GeneralPostTile({required this.request});

  final MatchRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          context.push('${AppRoutes.requestRoot}/${request.id}/general'),
      child: TtmTierCard(
        tier: TtmCardTier.feed,
        padding: const EdgeInsets.all(TtmSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GeneralRequestThumbnail(
                    imageUrl: request.thumbnailUrl,
                    size: 82,
                  ),
                ),
                const SizedBox(width: TtmSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.body.copyWith(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: TtmSpacing.sm),
                      Text(
                        request.rewardLabel(),
                        style: TtmTypography.moneyDisplay.copyWith(
                          fontSize: 18,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TtmSpacing.sm),
            Wrap(
              spacing: TtmSpacing.sm,
              runSpacing: TtmSpacing.xs,
              children: [
                _PostInfoPill(
                  icon: Icons.people_alt_outlined,
                  label: '지원 ${request.applicationCount}',
                ),
                _PostInfoPill(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '댓글 ${request.commentCount}',
                ),
                _PostInfoPill(
                  icon: Icons.category_outlined,
                  label: request.taskPolicy.type.label,
                ),
              ],
            ),
            const SizedBox(height: TtmSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '${AppRoutes.requestRoot}/${request.id}/general',
                    ),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('게시글 보기'),
                  ),
                ),
                const SizedBox(width: TtmSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                      '${AppRoutes.requestRoot}/${request.id}/edit',
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('수정'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostInfoPill extends StatelessWidget {
  const _PostInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TtmTypography.label.copyWith(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityWaitingCard extends StatefulWidget {
  const _ActivityWaitingCard();

  @override
  State<_ActivityWaitingCard> createState() => _ActivityWaitingCardState();
}

class _ActivityWaitingCardState extends State<_ActivityWaitingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
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

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: TtmTierCard(
        tier: TtmCardTier.mission,
        padding: const EdgeInsets.all(TtmSpacing.lg),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final scale = 0.92 + (_pulse.value * 0.12);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: semantic.missionAccent.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(
                          color: semantic.missionAccent.withValues(
                            alpha: 0.08 + _pulse.value * 0.14,
                          ),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.sensors_rounded,
                      color: semantic.missionAccent,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: TtmSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '진행 중인 ○○은 없어요',
                    style: TtmTypography.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '새로 지원하거나 수락한 작업이 생기면 여기에서 바로 이어갈 수 있어요.',
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
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.async,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onOpen,
  });

  final AsyncValue<List<MatchRequest>> async;
  final String emptyTitle;
  final String emptySubtitle;
  final void Function(String requestId) onOpen;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '활동 기록을 불러오지 못했어요.\n$e',
          textAlign: TextAlign.center,
          style: TtmTypography.body,
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return TtmEmptyState(
            iconAsset: 'assets/icons/check_circle.svg',
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: TtmSpacing.sm),
          itemBuilder: (context, index) {
            final item = list[index];
            return _HistoryRequestTile(
              request: item,
              onTap: () => onOpen(item.id),
            );
          },
        );
      },
    );
  }
}

class _HistoryRequestTile extends StatelessWidget {
  const _HistoryRequestTile({required this.request, required this.onTap});

  final MatchRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = NumberFormat.decimalPattern('ko');
    final completed = request.completedAt?.toLocal();
    final date = completed == null
        ? '-'
        : '${completed.month.toString().padLeft(2, '0')}.${completed.day.toString().padLeft(2, '0')} ${completed.hour.toString().padLeft(2, '0')}:${completed.minute.toString().padLeft(2, '0')}';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(TtmSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TtmTypography.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '완료 $date',
                      style: TtmTypography.body.copyWith(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TtmSpacing.md),
              Text(
                '₩${money.format(request.reward)}',
                style: TtmTypography.moneyDisplay.copyWith(
                  fontSize: 18,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsStat extends StatelessWidget {
  const _EarningsStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TtmTypography.body.copyWith(
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TtmTypography.metric.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}
