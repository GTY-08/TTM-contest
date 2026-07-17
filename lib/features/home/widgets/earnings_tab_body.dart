import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../shared/widgets/ttm_tier_card.dart';

/// 수익 탭 — fintech 대시보드 (MVP 플레이스홀더).
class EarningsTabBody extends StatelessWidget {
  const EarningsTabBody({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        TtmSpacing.lg,
        TtmSpacing.lg,
        100,
      ),
      children: [
        Text(
          '수익',
          style: TtmTypography.title.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: TtmSpacing.lg),
        TtmTierCard(
          tier: TtmCardTier.status,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘',
                style: TtmTypography.eyebrow.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TtmSpacing.xs),
              Text(
                '₩—',
                style: TtmTypography.moneyDisplay.copyWith(
                  fontSize: 36,
                  color: semantic.brandTeal,
                ),
              ),
              const SizedBox(height: TtmSpacing.sm),
              Text(
                '정산 전 · 주간·월간 추이는 곧 연결됩니다.',
                style: TtmTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TtmSpacing.md),
        Row(
          children: [
            Expanded(
              child: TtmTierCard(
                tier: TtmCardTier.status,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이번 주',
                      style: TtmTypography.eyebrow.copyWith(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₩—',
                      style: TtmTypography.metric.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: TtmSpacing.sm),
            Expanded(
              child: TtmTierCard(
                tier: TtmCardTier.status,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '완료',
                      style: TtmTypography.eyebrow.copyWith(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '—건',
                      style: TtmTypography.metric.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
