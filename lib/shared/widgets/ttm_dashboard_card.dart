import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/ttm_surface_style.dart';

/// 대시보드형 카드 — 레이어드 그림자 + 상단 하이라이트 그라데이션.
class TtmDashboardCard extends StatelessWidget {
  const TtmDashboardCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final surface = TtmSurfaceStyle.of(context);
    final bg = highlighted ? colors.surfaceContainerHighest : colors.surface;
    final borderColor = highlighted
        ? colors.primary.withValues(alpha: 0.45)
        : colors.outlineVariant.withValues(alpha: 0.4);

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TtmRadius.md),
        border: Border.all(color: borderColor),
        boxShadow: surface.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TtmRadius.md),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: surface.cardSheenGradient),
              ),
            ),
            Padding(
              padding: padding ?? const EdgeInsets.all(TtmSpacing.md),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TtmRadius.md),
        splashColor: colors.primary.withValues(alpha: 0.08),
        child: card,
      ),
    );
  }
}
