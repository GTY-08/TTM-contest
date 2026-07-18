import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../shared/widgets/ttm_scale_tap.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../models/raid_models.dart';

class RaidCard extends StatelessWidget {
  const RaidCard({
    super.key,
    required this.raid,
    required this.onTap,
    this.compact = false,
  });

  final Raid raid;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = DateFormat('M월 d일 (E) HH:mm', 'ko').format(raid.startsAt);
    final accent = raid.isPremiumRaid
        ? const Color(0xFFF0B84B)
        : TtmColors.primary;
    return TtmScaleTap(
      onTap: onTap,
      child: TtmTierCard(
        tier: TtmCardTier.feed,
        padding: const EdgeInsets.all(TtmSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(TtmRadius.md),
                  ),
                  child: Icon(_exerciseIcon(raid.exerciseType), color: accent),
                ),
                const SizedBox(width: TtmSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raid.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.title.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        start,
                        style: TtmTypography.label.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: raidStatusLabel(raid.status), color: accent),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: TtmSpacing.md),
              Text(
                raid.venue.name,
                style: TtmTypography.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                raid.venue.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TtmTypography.label.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: TtmSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (raid.distanceMeters != null)
                  _InfoChip(
                    icon: Icons.near_me_outlined,
                    text: raid.distanceMeters! < 1000
                        ? '${raid.distanceMeters}m'
                        : '${(raid.distanceMeters! / 1000).toStringAsFixed(1)}km',
                  ),
                _InfoChip(
                  icon: Icons.people_alt_outlined,
                  text:
                      '${raid.participantCount}/${raid.maxParticipants}명 · 최소 ${raid.minParticipants}명',
                ),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  text: '${raid.durationMinutes}분',
                ),
                _InfoChip(
                  icon: Icons.speed_outlined,
                  text: intensityLabel(raid.intensity),
                ),
                if (raid.beginnerFriendly)
                  const _InfoChip(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    text: '초보자 가능',
                  ),
                _InfoChip(
                  icon: raid.isPremiumRaid
                      ? Icons.groups_2_outlined
                      : Icons.auto_awesome_outlined,
                  text: raid.isPremiumRaid ? '일반 매칭' : '추천 레이드',
                ),
                if (raid.participationFee > 0)
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    text:
                        '${NumberFormat.decimalPattern('ko').format(raid.participationFee)}원',
                  ),
              ],
            ),
            if (raid.isMember || raid.isApplied) ...[
              const SizedBox(height: TtmSpacing.sm),
              Text(
                raid.isMember ? '참가가 확정됐어요' : '참가 신청을 확인하고 있어요',
                style: TtmTypography.label.copyWith(
                  color: raid.isMember ? TtmColors.primary : accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TtmTypography.label.copyWith(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: TtmTypography.label.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _exerciseIcon(String type) => switch (type) {
  'running' => Icons.directions_run_rounded,
  'walking' => Icons.directions_walk_rounded,
  'badminton' => Icons.sports_tennis_rounded,
  'basketball' => Icons.sports_basketball_rounded,
  'fitness' => Icons.fitness_center_rounded,
  _ => Icons.sports_rounded,
};
