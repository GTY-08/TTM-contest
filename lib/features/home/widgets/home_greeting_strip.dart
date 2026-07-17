import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../shared/widgets/ttm_premium_nickname.dart';

/// 홈 상단 인사 + 근처 요청 힌트.
class HomeGreetingStrip extends StatelessWidget {
  const HomeGreetingStrip({
    super.key,
    required this.nickname,
    required this.isPremium,
    required this.isOnline,
    required this.nearbyCount,
  });

  final String nickname;
  final bool isPremium;
  final bool isOnline;
  final int? nearbyCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final name = nickname.trim().isEmpty ? '이웃' : nickname.trim();

    String subtitle;
    if (!isOnline) {
      subtitle = '활동을 켜면 주변 심부름을 받을 수 있어요';
    } else if (nearbyCount == null) {
      subtitle = '주변 요청을 확인하는 중…';
    } else if (nearbyCount! > 0) {
      subtitle = '지금 근처에 요청 ${nearbyCount!}건이 있어요';
    } else {
      subtitle = '잠시 후 다시 확인해 보세요';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '안녕하세요, ',
              style: TtmTypography.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: colors.onSurface,
              ),
            ),
            Flexible(
              child: TtmPremiumNickname(
                nickname: '$name님',
                isPremium: isPremium,
                crownSize: 20,
                style: TtmTypography.title.copyWith(
                  fontSize: 20,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xs),
        Text(
          subtitle,
          style: TtmTypography.body.copyWith(
            fontSize: 14,
            color: isOnline && (nearbyCount ?? 0) > 0
                ? semantic.brandTeal
                : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
