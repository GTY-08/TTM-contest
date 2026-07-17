import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'ttm_scale_tap.dart';

/// 수락한 진행 1건 — 홈 [C] 컴팩트 배너.
class TtmCompactActiveJob extends StatelessWidget {
  const TtmCompactActiveJob({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TtmColors.primaryDark : TtmColors.primary;

    return TtmScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TtmSpacing.lg,
          vertical: TtmSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(TtmRadius.lg),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TtmTypography.title.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            Icon(Icons.chevron_right_rounded, color: accent, size: 24),
          ],
        ),
      ),
    );
  }
}
