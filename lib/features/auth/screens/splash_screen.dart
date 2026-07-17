import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ttm_fade_in.dart';

/// 스플래시 — 브랜드 + 짧은 페이드 인.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: TtmColors.primaryLight,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Positioned(
              left: -72,
              top: -96,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TtmColors.lightSurface.withValues(alpha: 0.34),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 220, height: 220),
              ),
            ),
            Positioned(
              right: -88,
              bottom: -120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TtmColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 260, height: 260),
              ),
            ),
            TtmFadeIn(
              duration: const Duration(milliseconds: 480),
              beginOffsetY: 12,
              scaleFrom: 0.96,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: TtmColors.lightSurface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: TtmColors.deepGreen.withValues(alpha: 0.14),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: SvgPicture.asset(
                        'assets/images/teumteum_app_icon.svg',
                        width: 104,
                        height: 104,
                      ),
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.lg),
                  Text(
                    '틈틈',
                    style: TtmTypography.display.copyWith(
                      color: colors.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                  Text(
                    '동네 심부름 매칭',
                    style: TtmTypography.label.copyWith(
                      color: TtmColors.deepGreen.withValues(alpha: 0.72),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
