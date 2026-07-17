import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/ui/graphic_policy.dart';

/// 빈 상태 — SVG 아이콘 + 카피.
class TtmEmptyState extends StatelessWidget {
  const TtmEmptyState({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    this.emoji,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    assert(
      emoji == null || emoji!.runes.length <= GraphicPolicy.maxEmojisPerScreen,
      '이모지는 화면당 소량만 허용합니다.',
    );

    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TtmSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 56,
                height: 56,
                colorFilter: ColorFilter.mode(colors.primary, BlendMode.srcIn),
              ),
              const SizedBox(height: TtmSpacing.lg),
              Text(
                title,
                style: TtmTypography.display.copyWith(color: colors.primary),
                textAlign: TextAlign.center,
              ),
              if (emoji != null) ...[
                const SizedBox(height: TtmSpacing.xs),
                Text(
                  emoji!,
                  style: const TextStyle(fontSize: 18, height: 1),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: TtmSpacing.sm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TtmTypography.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
