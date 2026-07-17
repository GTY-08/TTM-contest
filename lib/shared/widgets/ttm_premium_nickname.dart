import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// 닉네임 + 프리미엄 골드 왕관 배지.
class TtmPremiumNickname extends StatelessWidget {
  const TtmPremiumNickname({
    super.key,
    required this.nickname,
    required this.isPremium,
    this.style,
    this.crownSize = 18,
    this.maxLines = 1,
  });

  final String nickname;
  final bool isPremium;
  final TextStyle? style;
  final double crownSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        TtmTypography.title.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            nickname,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: base,
          ),
        ),
        if (isPremium) ...[
          const SizedBox(width: 5),
          SvgPicture.asset(
            'assets/icons/crown.svg',
            width: crownSize,
            height: crownSize,
            colorFilter: const ColorFilter.mode(
              TtmColors.premiumGold,
              BlendMode.srcIn,
            ),
          ),
        ],
      ],
    );
  }
}

/// 프리미엄 사용자 카드·헤더용 골드 테두리.
class TtmPremiumGoldFrame extends StatelessWidget {
  const TtmPremiumGoldFrame({
    super.key,
    required this.isPremium,
    required this.child,
    this.borderRadius = 12,
  });

  final bool isPremium;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!isPremium) return child;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: TtmColors.premiumGold.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: child,
      ),
    );
  }
}
