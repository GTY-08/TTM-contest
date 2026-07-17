import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/app_user.dart';
import '../../../shared/widgets/ttm_elevated_card.dart';
import '../../../shared/widgets/ttm_premium_nickname.dart';
import '../../profile/profile_copy.dart';
import '../../profile/widgets/profile_photo_change.dart';
import 'match_role_badge.dart';

/// DM 상대 프로필 — 아바타·닉네임·평점 등.
Future<void> showCounterpartProfileSheet(
  BuildContext context, {
  required AppUser user,
  required bool counterpartIsRequester,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      final bottom = MediaQuery.viewPaddingOf(context).bottom;

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            TtmSpacing.xl,
            TtmSpacing.sm,
            TtmSpacing.xl,
            TtmSpacing.xl + bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '상대 프로필',
                style: TtmTypography.title.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: TtmSpacing.lg),
              TtmPremiumGoldFrame(
                isPremium: user.isPremium,
                child: TtmElevatedCard(
                  child: Column(
                    children: [
                      if (user.isPremium)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(
                              bottom: TtmSpacing.sm,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: TtmColors.premiumGold.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ProfileCopy.premiumActiveLabel,
                              style: TtmTypography.label.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: TtmColors.premiumGold,
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          TtmProfileAvatar(
                            imageUrl: user.profileImageUrl,
                            size: 72,
                          ),
                          const SizedBox(width: TtmSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MatchRoleBadge(
                                  isRequester: counterpartIsRequester,
                                  compact: false,
                                ),
                                const SizedBox(height: 6),
                                TtmPremiumNickname(
                                  nickname: user.nickname,
                                  isPremium: user.isPremium,
                                  crownSize: 22,
                                  style: TtmTypography.title.copyWith(
                                    fontSize: 20,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ProfileCopy.ratingLine(
                                    user.rating,
                                    user.ratingCount,
                                  ),
                                  style: TtmTypography.body.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
