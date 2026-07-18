import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../shared/widgets/ttm_empty_state.dart';
import '../../../shared/widgets/ttm_section_header.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../providers/raid_providers.dart';
import '../widgets/raid_card.dart';

class RaidActivityTab extends ConsumerWidget {
  const RaidActivityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raids = ref.watch(myRaidsProvider);
    final rewards = ref.watch(rewardSummaryProvider).valueOrNull;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myRaidsProvider);
        ref.invalidate(rewardSummaryProvider);
        await ref.read(myRaidsProvider.future);
      },
      child: raids.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ListView(
          padding: const EdgeInsets.all(TtmSpacing.lg),
          children: const [
            TtmEmptyState(
              title: '활동 기록을 불러오지 못했어요',
              subtitle: '아래로 당겨 다시 확인해 주세요.',
              iconAsset: 'assets/icons/bolt.svg',
            ),
          ],
        ),
        data: (items) {
          final active = items
              .where(
                (raid) => !{'completed', 'cancelled'}.contains(raid.status),
              )
              .toList(growable: false);
          final history = items
              .where((raid) => {'completed', 'cancelled'}.contains(raid.status))
              .toList(growable: false);
          final completed = history
              .where((raid) => raid.status == 'completed')
              .length;
          final minutes = history
              .where(
                (raid) =>
                    raid.status == 'completed' &&
                    raid.myParticipant?.attendanceStatus != 'absent',
              )
              .fold<int>(0, (sum, raid) => sum + raid.durationMinutes);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.md,
              TtmSpacing.lg,
              120,
            ),
            children: [
              Text(
                '내 운동 활동',
                style: TtmTypography.display.copyWith(fontSize: 24),
              ),
              const SizedBox(height: TtmSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _Metric(label: '완료 레이드', value: '$completed회'),
                  ),
                  const SizedBox(width: TtmSpacing.sm),
                  Expanded(
                    child: _Metric(label: '누적 운동', value: '$minutes분'),
                  ),
                  const SizedBox(width: TtmSpacing.sm),
                  Expanded(
                    child: _Metric(
                      label: '활동 포인트',
                      value: '${rewards?.lifetimePoints ?? 0}P',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TtmSpacing.xl),
              const TtmSectionHeader(title: '진행 중인 레이드'),
              const SizedBox(height: TtmSpacing.sm),
              if (active.isEmpty)
                const TtmEmptyState(
                  title: '진행 중인 레이드가 없어요',
                  subtitle: '주변 레이드에서 새로운 운동을 찾아보세요.',
                  iconAsset: 'assets/icons/check_circle.svg',
                )
              else
                for (final raid in active) ...[
                  RaidCard(
                    raid: raid,
                    onTap: () =>
                        context.push('${AppRoutes.raidRoot}/${raid.id}'),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                ],
              const SizedBox(height: TtmSpacing.xl),
              const TtmSectionHeader(title: '운동 기록'),
              const SizedBox(height: TtmSpacing.sm),
              if (history.isEmpty)
                const TtmEmptyState(
                  title: '아직 운동 기록이 없어요',
                  subtitle: '레이드에 참여하면 운동 기록이 차곡차곡 쌓여요.',
                  iconAsset: 'assets/icons/clock.svg',
                )
              else
                for (final raid in history) ...[
                  RaidCard(
                    raid: raid,
                    compact: true,
                    onTap: () =>
                        context.push('${AppRoutes.raidRoot}/${raid.id}'),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => TtmTierCard(
    tier: TtmCardTier.status,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    child: Column(
      children: [
        Text(value, style: TtmTypography.metric.copyWith(fontSize: 17)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TtmTypography.label.copyWith(fontSize: 10),
        ),
      ],
    ),
  );
}
