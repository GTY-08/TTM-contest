import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/ttm_surface_style.dart';
import 'ttm_scale_tap.dart';

/// 카드 공통 — 부드러운 그림자 + 16dp radius.
class TtmElevatedCard extends StatelessWidget {
  const TtmElevatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.urgent = false,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool urgent;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final surface = TtmSurfaceStyle.of(context);

    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(TtmSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TtmRadius.card),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: surface.cardShadow,
      ),
      child: child,
    );

    if (urgent) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TtmRadius.card),
          boxShadow: [
            BoxShadow(
              color: colors.error.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TtmRadius.card),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: colors.error),
              ),
              card,
            ],
          ),
        ),
      );
    }

    if (onTap != null) {
      return TtmScaleTap(onTap: onTap!, child: card);
    }
    return card;
  }
}
