import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// 화면 상단 일러스트 SVG — Primary Light 배경 카드.
class TtmIllustrationHero extends StatelessWidget {
  const TtmIllustrationHero({
    super.key,
    required this.asset,
    this.height = 112,
  });

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TtmRadius.xl),
        color: scheme.primaryContainer.withValues(alpha: 0.28),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: TtmSpacing.md,
          horizontal: TtmSpacing.sm,
        ),
        child: Center(
          child: SvgPicture.asset(asset, height: height, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
