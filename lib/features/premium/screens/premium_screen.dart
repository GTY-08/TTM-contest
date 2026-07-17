import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/premium_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../features/profile/profile_copy.dart';
import '../../../features/settings/screens/settings_screen.dart';
import '../../../features/settings/settings_copy.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_elevated_card.dart';

/// 틈틈 프리미엄 — Play 구독 전에는 설정 테스트 토글 사용.
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
            padding: const EdgeInsets.all(TtmSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SettingsCopy.premiumTestBannerTitle,
                  style: TtmTypography.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TtmSpacing.sm),
                Text(
                  SettingsCopy.premiumTestBannerBody,
                  style: TtmTypography.body.copyWith(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: TtmSpacing.md),
                TTMButton(
                  label: '설정에서 프리미엄 모드 켜기',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(initialTab: 4),
                    ),
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
                Text(
                  isPremium ? '프리미엄 사용 중' : '프리미엄 혜택',
                  style: TtmTypography.title.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: TtmSpacing.sm),
                Text(
                  TtmPremiumConstants.listPriceLabel,
                  style: TtmTypography.moneyDisplay.copyWith(
                    fontSize: 28,
                    color: TtmColors.premiumGold,
                  ),
                ),
                const SizedBox(height: TtmSpacing.md),
                _benefit('수수료 10% → 5%'),
                _benefit('요청·작업 합산 동시 최대 3건'),
                _benefit('닉네임 옆 골드 왕관 배지'),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.xl),
          Text(
            'Google Play 정기결제(${TtmPremiumConstants.listPriceLabel})는 '
            '개발자 등록(만 18세) 후 연결할 예정이에요.',
            style: TtmTypography.label.copyWith(
              fontSize: 11,
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TtmSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 18, color: TtmColors.primary),
          const SizedBox(width: TtmSpacing.sm),
          Expanded(
            child: Text(text, style: TtmTypography.body.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
