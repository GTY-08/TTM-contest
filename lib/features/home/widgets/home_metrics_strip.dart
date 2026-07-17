import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../shared/widgets/ttm_tier_card.dart';

/// 홈 Tier2 — 오늘 지표 4칸.
class HomeMetricsStrip extends StatelessWidget {
  const HomeMetricsStrip({
    super.key,
    required this.nearbyCount,
    required this.todayEarnings,
    required this.rating,
    required this.ratingCount,
    required this.activeSlots,
    required this.slotLimit,
  });

  final int nearbyCount;
  final int todayEarnings;
  final double? rating;
  final int ratingCount;
  final int activeSlots;
  final int slotLimit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);

    final ratingText = rating == null
        ? '—'
        : '${rating!.toStringAsFixed(1)}${ratingCount > 0 ? ' ($ratingCount)' : ''}';
    final money = NumberFormat.decimalPattern('ko');

    return TtmTierCard(
      tier: TtmCardTier.status,
      padding: const EdgeInsets.symmetric(
        horizontal: TtmSpacing.sm,
        vertical: TtmSpacing.md,
      ),
      child: Row(
        children: [
          _MetricCell(
            label: '오늘 예상',
            value: '₩${money.format(todayEarnings)}',
            valueColor: semantic.brandTeal,
          ),
          _divider(colors),
          _MetricCell(label: '근처 요청', value: '$nearbyCount건'),
          _divider(colors),
          _MetricCell(label: '평점', value: ratingText),
          _divider(colors),
          _MetricCell(label: '진행 슬롯', value: '$activeSlots/$slotLimit'),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme colors) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: TtmSpacing.xs),
      color: colors.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TtmTypography.eyebrow.copyWith(
              fontSize: 10,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TtmTypography.moneyDisplay.copyWith(
              fontSize: label == '오늘 예상' ? 15 : 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
