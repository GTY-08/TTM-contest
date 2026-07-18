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
import '../../../data/providers/home_navigation_provider.dart';
import '../../../shared/widgets/ttm_empty_state.dart';
import '../../../shared/widgets/ttm_section_header.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../models/exercise_matching_models.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';
import '../services/exercise_location_service.dart';
import '../widgets/raid_card.dart';

class RaidHomeTab extends ConsumerWidget {
  const RaidHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final rewards = ref.watch(rewardSummaryProvider);
    final nearby = ref.watch(nearbyRaidsProvider);
    final mine = ref.watch(myRaidsProvider);
    final top = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nearbyRaidsProvider);
        ref.invalidate(myRaidsProvider);
        ref.invalidate(rewardSummaryProvider);
        ref.invalidate(raidRecruitmentOffersProvider);
        await Future.wait([
          ref.read(nearbyRaidsProvider.future),
          ref.read(myRaidsProvider.future),
          ref.read(rewardSummaryProvider.future),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          TtmSpacing.lg,
          top + TtmSpacing.md,
          TtmSpacing.lg,
          120,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile?.nickname ?? ''}님,',
                      style: TtmTypography.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '오늘 함께 움직여볼까요?',
                      style: TtmTypography.display.copyWith(fontSize: 23),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(homeTabIndexProvider.notifier).state = 5,
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: TtmColors.primary.withValues(alpha: 0.12),
                  backgroundImage: profile?.profileImageUrl == null
                      ? null
                      : NetworkImage(profile!.profileImageUrl!),
                  child: profile?.profileImageUrl == null
                      ? const Icon(
                          Icons.person_outline,
                          color: TtmColors.primary,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.md),
          const _RecruitmentOffersSection(),
          const SizedBox(height: TtmSpacing.lg),
          rewards.when(
            loading: () => const _LevelCardSkeleton(),
            error: (_, _) => const SizedBox.shrink(),
            data: (summary) => _LevelCard(summary: summary),
          ),
          const SizedBox(height: TtmSpacing.md),
          TtmTierCard(
            tier: TtmCardTier.mission,
            padding: const EdgeInsets.all(TtmSpacing.lg),
            onTap: () => context.push(AppRoutes.quickMatch),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: TtmSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '지금 운동 매칭',
                        style: TtmTypography.title.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '가까운 운동 파트너를 바로 찾아요',
                        style: TtmTypography.label.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.lg),
          mine.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) {
              final next =
                  items
                      .where(
                        (raid) =>
                            raid.myParticipant?.isApproved == true &&
                            raid.status != 'completed' &&
                            raid.status != 'cancelled',
                      )
                      .toList()
                    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
              if (next.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TtmSectionHeader(title: '다음 레이드'),
                  const SizedBox(height: TtmSpacing.sm),
                  RaidCard(
                    raid: next.first,
                    onTap: () =>
                        context.push('${AppRoutes.raidRoot}/${next.first.id}'),
                  ),
                  const SizedBox(height: TtmSpacing.lg),
                ],
              );
            },
          ),
          Row(
            children: [
              const Expanded(child: TtmSectionHeader(title: '내 주변 레이드')),
              TextButton(
                onPressed: () =>
                    ref.read(homeTabIndexProvider.notifier).state = 2,
                child: const Text('전체 보기'),
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.sm),
          nearby.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => TtmEmptyState(
              title: '레이드를 불러오지 못했어요',
              subtitle: '잠시 후 아래로 당겨 다시 확인해 주세요.',
              iconAsset: 'assets/icons/bolt.svg',
            ),
            data: (feed) {
              final items = feed.raids;
              if (items.isEmpty) {
                return TtmEmptyState(
                  title: '아직 예정된 레이드가 없어요',
                  subtitle: '새 레이드가 열리면 이곳에서 바로 확인할 수 있어요.',
                  iconAsset: 'assets/icons/map.svg',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!feed.isNearby) ...[
                    Text(
                      '위치 권한을 허용하면 5km 이내 레이드만 보여드려요. 지금은 예정된 레이드를 표시합니다.',
                      style: TtmTypography.label.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.sm),
                  ],
                  for (final raid in items.take(4)) ...[
                    RaidCard(
                      raid: raid,
                      onTap: () =>
                          context.push('${AppRoutes.raidRoot}/${raid.id}'),
                    ),
                    const SizedBox(height: TtmSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecruitmentOffersSection extends ConsumerStatefulWidget {
  const _RecruitmentOffersSection();

  @override
  ConsumerState<_RecruitmentOffersSection> createState() =>
      _RecruitmentOffersSectionState();
}

class _RecruitmentOffersSectionState
    extends ConsumerState<_RecruitmentOffersSection> {
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(raidRecruitmentOffersProvider);
    return offers.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtmSectionHeader(title: '지금 참가할 수 있는 레이드'),
            const SizedBox(height: TtmSpacing.sm),
            for (final offer in items) ...[
              _RecruitmentOfferCard(
                offer: offer,
                busy: _busyId == offer.id,
                onOpen: () =>
                    context.push('${AppRoutes.raidRoot}/${offer.raidId}'),
                onAccept: () => _respond(offer, true),
                onDecline: () => _respond(offer, false),
              ),
              const SizedBox(height: TtmSpacing.sm),
            ],
            const SizedBox(height: TtmSpacing.md),
          ],
        );
      },
    );
  }

  Future<void> _respond(RaidRecruitmentOffer offer, bool accept) async {
    if (_busyId != null) return;
    setState(() => _busyId = offer.id);
    try {
      ExerciseLocationSnapshot? location;
      if (accept) {
        location = await ref.read(exerciseLocationServiceProvider).current();
      }
      final result = await ref
          .read(raidRepositoryProvider)
          .respondRaidRecruitmentOffer(
            offerId: offer.id,
            accept: accept,
            location: location,
          );
      if (!mounted) return;
      final message = result['ok'] == true
          ? (accept
                ? result['approval_status'] == 'approved'
                      ? '레이드 참가가 확정됐어요.'
                      : '레이드 참가 신청을 보냈어요.'
                : '이번 제안을 거절했어요.')
          : exerciseLocationMessage(result['reason']?.toString() ?? '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      ref.invalidate(raidRecruitmentOffersProvider);
      ref.invalidate(myRaidsProvider);
      ref.invalidate(nearbyRaidsProvider);
    } on ExerciseLocationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exerciseLocationMessage(error.reason))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _RecruitmentOfferCard extends StatelessWidget {
  const _RecruitmentOfferCard({
    required this.offer,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
  });

  final RaidRecruitmentOffer offer;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final distance = offer.distanceMeters == null
        ? ''
        : ' · ${(offer.distanceMeters! / 1000).toStringAsFixed(1)}km';
    return TtmTierCard(
      tier: TtmCardTier.feed,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(offer.title, style: TtmTypography.title),
          const SizedBox(height: 4),
          Text(
            '${offer.venueName}$distance · ${exerciseLabel(offer.exerciseType)}',
            style: TtmTypography.body,
          ),
          const SizedBox(height: TtmSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('이번에는 어려워요'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: Text(
                    offer.approvalMode == 'instant' ? '바로 참가' : '참가 신청',
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

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.summary});
  final RewardSummary summary;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern('ko');
    return TtmTierCard(
      tier: TtmCardTier.mission,
      padding: const EdgeInsets.all(TtmSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white),
              ),
              const SizedBox(width: TtmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.${summary.level} ${summary.levelTitle}',
                      style: TtmTypography.title.copyWith(color: Colors.white),
                    ),
                    Text(
                      '사용 가능 ${number.format(summary.availablePoints)}P',
                      style: TtmTypography.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: summary.levelProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.nextRequiredPoints == null
                ? '최고 레벨에 도달했어요'
                : '다음 레벨까지 ${number.format(summary.nextRequiredPoints! - summary.lifetimePoints)}P',
            style: TtmTypography.label.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCardSkeleton extends StatelessWidget {
  const _LevelCardSkeleton();

  @override
  Widget build(BuildContext context) =>
      TtmTierCard(tier: TtmCardTier.status, child: const SizedBox(height: 108));
}
