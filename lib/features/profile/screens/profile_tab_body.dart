import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/received_review.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../features/raid/providers/raid_providers.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_elevated_card.dart';
import '../../../shared/widgets/ttm_empty_state.dart';
import '../../../shared/widgets/ttm_fade_in.dart';
import '../../../shared/widgets/ttm_premium_nickname.dart';
import '../../../shared/widgets/ttm_section_header.dart';
import '../profile_copy.dart';
import '../widgets/profile_photo_change.dart';
import 'nickname_edit_screen.dart';

/// 홈 프로필 탭 본문.
class ProfileTabBody extends ConsumerWidget {
  const ProfileTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(myProfileProvider);
    final activityAsync = ref.watch(exerciseActivitySummaryProvider);
    final receivedReviewsAsync = ref.watch(myReceivedReviewsProvider);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: profileAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: colors.primary)),
        error: (_, _) => const Center(child: Text('프로필을 불러오지 못했어요.')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('프로필을 불러오지 못했어요.'));
          }
          final navBottom = MediaQuery.paddingOf(context).bottom;
          return TtmFadeIn(
            duration: TtmMotion.standard,
            beginOffsetY: 8,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                TtmSpacing.xl,
                TtmSpacing.lg,
                TtmSpacing.xl,
                navBottom + 32,
              ),
              children: [
                // ── 프로필 카드 ───────────────────────────────────
                _ProfileHeaderCard(
                  user: user,
                  onPhotoChange: () =>
                      ProfilePhotoChangeHandler.start(context, ref, user: user),
                ),
                const SizedBox(height: TtmSpacing.lg),
                if (!user.isPremium) _PremiumCard(isPremium: user.isPremium),
                if (!user.isPremium) const SizedBox(height: TtmSpacing.lg),

                // ── 신뢰 정보 ────────────────────────────────────
                const TtmSectionHeader(title: '신뢰 정보'),
                _TrustCard(user: user),

                const TtmSectionHeader(title: '운동 설정'),
                TtmElevatedCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: TtmSpacing.lg,
                      vertical: TtmSpacing.sm,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1F0B7A75),
                      child: Icon(
                        Icons.directions_run_rounded,
                        color: TtmColors.primary,
                      ),
                    ),
                    title: const Text('내 운동 조건'),
                    subtitle: const Text('활동 지역 · 선호 종목 · 수준 · 가능한 시간'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.exercisePreferences),
                  ),
                ),

                // ── 활동 기록 ────────────────────────────────────
                const TtmSectionHeader(title: '활동 기록'),
                _ActivitySummaryCard(
                  hostedCount: activityAsync.valueOrNull?.hostedCount,
                  participatedCount:
                      activityAsync.valueOrNull?.participatedCount,
                  receivedReviewCount:
                      receivedReviewsAsync.valueOrNull?.length ??
                      user.ratingCount,
                ),

                // ── 받은 후기 ────────────────────────────────────
                const TtmSectionHeader(title: '받은 후기'),
                _ReceivedReviewsSection(asyncReviews: receivedReviewsAsync),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── 프로필 헤더 카드 ─────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.user, required this.onPhotoChange});

  final AppUser user;
  final VoidCallback onPhotoChange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final card = TtmElevatedCard(
      child: Column(
        children: [
          if (user.isPremium)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: TtmSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: TtmColors.premiumGold.withValues(alpha: 0.2),
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
              TtmProfileAvatar(imageUrl: user.profileImageUrl, size: 72),
              const SizedBox(width: TtmSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TtmPremiumNickname(
                      nickname: user.nickname,
                      isPremium: user.isPremium,
                      crownSize: 22,
                      style: TtmTypography.title.copyWith(
                        fontSize: 22,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ProfileCopy.ratingLine(user.rating, user.ratingCount),
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
          const SizedBox(height: TtmSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TTMButton(
                  label: ProfileCopy.photoChange,
                  variant: TtmButtonVariant.secondary,
                  expanded: true,
                  onPressed: onPhotoChange,
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              Expanded(
                child: TTMButton(
                  label: ProfileCopy.nicknameEdit,
                  expanded: true,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NicknameEditScreen(initialNickname: user.nickname),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!user.isPremium) return card;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: TtmColors.premiumGold.withValues(alpha: 0.28),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: card,
    );
  }
}

// ── 프리미엄 카드 ────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final card = TtmElevatedCard(
      padding: const EdgeInsets.all(TtmSpacing.lg),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/crown.svg',
            width: 28,
            height: 28,
            colorFilter: const ColorFilter.mode(
              TtmColors.premiumGold,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: TtmSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ProfileCopy.premiumTitle,
                  style: TtmTypography.title.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? '구독 중 · ${ProfileCopy.premiumBenefits}'
                      : ProfileCopy.premiumBenefits,
                  style: TtmTypography.body.copyWith(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.premium),
            child: Text(
              ProfileCopy.premiumCta,
              style: TtmTypography.label.copyWith(
                color: TtmColors.premiumGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return TtmPremiumGoldFrame(isPremium: isPremium, child: card);
  }
}

// ── 신뢰 정보 카드 ───────────────────────────────────────────────

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasPenalty =
        user.hasActiveRequesterPenalty || user.hasActiveWorkerPenalty;

    return TtmElevatedCard(
      padding: const EdgeInsets.all(TtmSpacing.lg),
      child: _TrustRow(
        icon: Icons.block_outlined,
        label: '활동 제한',
        status: hasPenalty ? '제한 있음' : '제한 없음',
        statusColor: hasPenalty ? colors.error : TtmColors.deepGreen,
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.statusColor,
  });

  final IconData icon;
  final String label;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: statusColor),
        ),
        const SizedBox(width: TtmSpacing.md),
        Expanded(
          child: Text(label, style: TtmTypography.title.copyWith(fontSize: 16)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TtmTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 활동 기록 요약 카드 ──────────────────────────────────────────

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.hostedCount,
    required this.participatedCount,
    required this.receivedReviewCount,
  });

  final int? hostedCount;
  final int? participatedCount;
  final int receivedReviewCount;

  @override
  Widget build(BuildContext context) {
    return TtmElevatedCard(
      padding: const EdgeInsets.symmetric(
        horizontal: TtmSpacing.lg,
        vertical: TtmSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: hostedCount == null ? '...' : '$hostedCount건',
            label: '운영한 매칭',
          ),
          _VertDivider(),
          _StatItem(
            value: participatedCount == null ? '...' : '$participatedCount건',
            label: '참여한 운동',
          ),
          _VertDivider(),
          _StatItem(value: '$receivedReviewCount개', label: '받은 후기'),
        ],
      ),
    );
  }
}

class _ReceivedReviewsSection extends StatelessWidget {
  const _ReceivedReviewsSection({required this.asyncReviews});

  final AsyncValue<List<ReceivedReview>> asyncReviews;

  @override
  Widget build(BuildContext context) {
    return asyncReviews.when(
      loading: () => const TtmElevatedCard(
        child: Padding(
          padding: EdgeInsets.all(TtmSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => const TtmEmptyState(
        iconAsset: 'assets/icons/check_circle.svg',
        title: '후기를 불러오지 못했어요',
        subtitle: '잠시 후 다시 확인해 주세요',
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const TtmEmptyState(
            iconAsset: 'assets/icons/check_circle.svg',
            title: '아직 후기가 없어요',
            subtitle: '함께 운동한 사용자가 남긴 후기가 여기에 쌓여요',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < reviews.length; i++) ...[
              if (i > 0) const SizedBox(height: TtmSpacing.sm),
              _ReceivedReviewTile(review: reviews[i]),
            ],
          ],
        );
      },
    );
  }
}

class _ReceivedReviewTile extends StatelessWidget {
  const _ReceivedReviewTile({required this.review});

  final ReceivedReview review;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final created = review.createdAt?.toLocal();
    final date = created == null
        ? ''
        : '${created.year}.${created.month.toString().padLeft(2, '0')}.${created.day.toString().padLeft(2, '0')}';
    final comment = review.comment.isEmpty ? '작성된 글 후기는 없어요.' : review.comment;

    return TtmElevatedCard(
      padding: const EdgeInsets.all(TtmSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '★ ${review.rating}',
                style: TtmTypography.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              const Spacer(),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: TtmTypography.body.copyWith(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TtmSpacing.xs),
          Text(
            comment,
            style: TtmTypography.body.copyWith(
              fontSize: 14,
              height: 1.45,
              color: review.comment.isEmpty
                  ? colors.onSurfaceVariant
                  : colors.onSurface,
              fontStyle: review.comment.isEmpty ? FontStyle.italic : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: TtmTypography.metric.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TtmTypography.body.copyWith(
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 50,
      child: VerticalDivider(
        color: colors.outlineVariant.withValues(alpha: 0.4),
        width: 1,
      ),
    );
  }
}
