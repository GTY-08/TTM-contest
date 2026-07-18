import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/premium_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../features/profile/profile_copy.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_elevated_card.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isPremium =
        ref.watch(myProfileProvider).valueOrNull?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text(ProfileCopy.premiumTitle)),
      body: ListView(
        padding: const EdgeInsets.all(TtmSpacing.lg),
        children: [
          TtmElevatedCard(
            padding: const EdgeInsets.all(TtmSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? '프리미엄 이용 중' : '내가 만드는 운동 레이드',
                  style: TtmTypography.display.copyWith(fontSize: 23),
                ),
                const SizedBox(height: TtmSpacing.sm),
                Text(
                  isPremium
                      ? '원하는 장소와 시간에 레이드를 만들고 참가자를 운영할 수 있어요.'
                      : '함께 운동할 사람을 직접 모으고 활동 기록을 더 자세히 관리하세요.',
                  style: TtmTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: TtmSpacing.lg),
                Text(
                  TtmPremiumConstants.listPriceLabel,
                  style: TtmTypography.moneyDisplay.copyWith(
                    fontSize: 28,
                    color: TtmColors.premiumGold,
                  ),
                ),
                Text(
                  '매월',
                  style: TtmTypography.label.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.lg),
          TtmElevatedCard(
            padding: const EdgeInsets.all(TtmSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('프리미엄 혜택', style: TtmTypography.headline),
                const SizedBox(height: TtmSpacing.md),
                _benefit('등록된 운동 장소에서 레이드 직접 개설'),
                _benefit('참가 신청자 승인과 정원 관리'),
                _benefit('레이드별 참가비와 취소 기준 설정'),
                _benefit('누적 운동 시간과 활동 통계 확인'),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.xl),
          TTMButton(
            label: isPremium ? '프리미엄 이용 중' : '프리미엄 시작하기',
            onPressed: isPremium
                ? null
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('프리미엄 가입은 순차적으로 제공될 예정이에요.')),
                  ),
          ),
          const SizedBox(height: TtmSpacing.md),
          Text(
            '참가비는 레이드 완료 전까지 보관되며 취소 기준에 따라 반환됩니다.',
            textAlign: TextAlign.center,
            style: TtmTypography.label.copyWith(
              fontSize: 11,
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TtmSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 18, color: TtmColors.primary),
          const SizedBox(width: TtmSpacing.sm),
          Expanded(
            child: Text(text, style: TtmTypography.body.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
