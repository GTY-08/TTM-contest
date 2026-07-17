import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/ttm_card_tier.dart';
import '../../core/theme/ttm_semantic_colors.dart';
import '../../core/theme/ttm_surface_style.dart';

/// Tier별 카드 셸 — Mission / Status / Feed 시각 규칙.
class TtmTierCard extends StatefulWidget {
  const TtmTierCard({
    super.key,
    required this.tier,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColorOverride,
  });

  final TtmCardTier tier;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColorOverride;

  @override
  State<TtmTierCard> createState() => _TtmTierCardState();
}

// tier 가 mission ↔ 다른 값으로 바뀔 때 컨트롤러를 재생성하므로
// 티커를 한 번만 허용하는 SingleTickerProviderStateMixin 은 쓸 수 없다.
class _TtmTierCardState extends State<TtmTierCard>
    with TickerProviderStateMixin {
  AnimationController? _pulseCtl;

  @override
  void initState() {
    super.initState();
    if (widget.tier == TtmCardTier.mission) {
      _pulseCtl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TtmTierCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tier == TtmCardTier.mission && _pulseCtl == null) {
      _pulseCtl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat(reverse: true);
    } else if (widget.tier != TtmCardTier.mission) {
      _pulseCtl?.dispose();
      _pulseCtl = null;
    }
  }

  @override
  void dispose() {
    _pulseCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final surface = TtmSurfaceStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final EdgeInsets pad = switch (widget.tier) {
      TtmCardTier.mission =>
        widget.padding as EdgeInsets? ?? const EdgeInsets.all(TtmSpacing.lg),
      TtmCardTier.status =>
        widget.padding as EdgeInsets? ??
            const EdgeInsets.symmetric(
              horizontal: TtmSpacing.md,
              vertical: TtmSpacing.sm,
            ),
      TtmCardTier.feed =>
        widget.padding as EdgeInsets? ?? const EdgeInsets.all(TtmSpacing.md),
    };

    Color bg;
    Color borderColor;
    List<BoxShadow> shadows;
    Gradient? gradient;

    switch (widget.tier) {
      case TtmCardTier.mission:
        bg = isDark ? colors.surfaceContainerHighest : colors.surface;
        borderColor = semantic.missionAccent.withValues(
          alpha: isDark ? 0.55 : 0.35,
        );
        shadows = [
          ...surface.cardShadow,
          if (isDark)
            BoxShadow(
              color: semantic.missionAccent.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ];
        gradient = isDark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primaryContainer.withValues(alpha: 0.5),
                  colors.surface,
                ],
              );
      case TtmCardTier.status:
        bg = colors.surface;
        borderColor = colors.outlineVariant.withValues(alpha: 0.35);
        shadows = surface.cardShadow;
        gradient = null;
      case TtmCardTier.feed:
        bg = colors.surface;
        borderColor = colors.outlineVariant.withValues(alpha: 0.4);
        shadows = surface.cardShadow;
        gradient = null;
    }
    borderColor = widget.borderColorOverride ?? borderColor;

    final radius = widget.tier == TtmCardTier.mission
        ? TtmRadius.lg
        : TtmRadius.md;

    Widget inner = Stack(
      children: [
        if (widget.tier != TtmCardTier.mission)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: surface.cardSheenGradient),
            ),
          ),
        Padding(padding: pad, child: widget.child),
      ],
    );

    Widget card = AnimatedBuilder(
      animation: _pulseCtl ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) {
        final pulseBorder =
            widget.tier == TtmCardTier.mission && _pulseCtl != null
            ? Border.all(
                color: Color.lerp(
                  borderColor,
                  semantic.missionAccent.withValues(alpha: 0.85),
                  _pulseCtl!.value * 0.35,
                )!,
                width: 1.5,
              )
            : Border.all(color: borderColor);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: gradient == null ? bg : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(radius),
            border: pulseBorder,
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: inner,
          ),
        );
      },
    );

    if (widget.onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(TtmRadius.lg),
        splashColor: semantic.missionAccent.withValues(alpha: 0.08),
        child: card,
      ),
    );
  }
}
