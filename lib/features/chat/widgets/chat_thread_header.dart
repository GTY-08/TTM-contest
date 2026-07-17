import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/display_nickname.dart';
import '../../../data/models/app_user.dart';
import '../../../shared/widgets/ttm_premium_nickname.dart';
import '../../profile/widgets/profile_photo_change.dart';
import 'match_role_badge.dart';

/// DM 상단 — 상대 아바타·닉네임·역할.
class ChatThreadHeader extends StatelessWidget {
  const ChatThreadHeader({
    super.key,
    required this.isRequester,
    required this.counterpart,
    this.loading = false,
    this.onProfileTap,
  });

  final bool isRequester;
  final AppUser? counterpart;
  final bool loading;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = ttmDisplayNickname(counterpart?.nickname);
    final canTap = onProfileTap != null && counterpart != null && !loading;

    return Material(
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: canTap ? onProfileTap : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TtmSpacing.lg,
                TtmSpacing.md,
                TtmSpacing.lg,
                TtmSpacing.sm,
              ),
              child: Row(
                children: [
                  if (loading)
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    TtmProfileAvatar(
                      imageUrl: counterpart?.profileImageUrl,
                      size: 44,
                      borderWidth: 1.5,
                    ),
                  const SizedBox(width: TtmSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TtmPremiumNickname(
                          nickname: loading ? '불러오는 중…' : name,
                          isPremium: counterpart?.isPremium ?? false,
                          crownSize: 20,
                          style: TtmTypography.title.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            MatchRoleBadge(
                              isRequester: !isRequester,
                              compact: true,
                            ),
                            const SizedBox(width: TtmSpacing.sm),
                            Text(
                              isRequester ? '작업자' : '요청자',
                              style: TtmTypography.label.copyWith(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            if (canTap) ...[
                              const SizedBox(width: TtmSpacing.sm),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
