import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/user_restriction.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/user_restriction_notice.dart';

/// 맡기기 탭 — 심부름 요청 랜딩 페이지.
class RequestTabBody extends ConsumerWidget {
  const RequestTabBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    final restrictions =
        ref.watch(myActiveRestrictionsProvider).valueOrNull ?? const [];
    final requestBlocked = restrictions.blocksRequest;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 680;
          final iconSize = compact ? 88.0 : 100.0;
          final horizontal = constraints.maxWidth < 380
              ? TtmSpacing.lg
              : TtmSpacing.xl;
          final navClearance = 96.0 + bottom;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              compact ? TtmSpacing.lg : TtmSpacing.xl,
              horizontal,
              navClearance,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - navClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: top > 0 ? 0 : TtmSpacing.sm),
                  Text(
                    '심부름 맡기기',
                    style: TtmTypography.display.copyWith(
                      fontSize: compact ? 28 : 32,
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                  Text(
                    '만남 위치와 보상을 정하면\n주변 이웃에게 바로 알려드려요.',
                    style: TtmTypography.body.copyWith(
                      fontSize: compact ? 15 : 17,
                      height: 1.45,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: compact ? TtmSpacing.xl : 32),
                  Center(
                    child: Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: TtmColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(iconSize * 0.25),
                        child: SvgPicture.asset(
                          'assets/icons/plus_circle.svg',
                          colorFilter: const ColorFilter.mode(
                            TtmColors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? TtmSpacing.xl : 32),
                  const UserRestrictionNotice(
                    onlyBlockingRequest: true,
                    compact: true,
                  ),
                  if (requestBlocked) const SizedBox(height: TtmSpacing.lg),
                  const _HowItWorksCard(),
                  const SizedBox(height: TtmSpacing.lg),
                  TTMButton(
                    label: requestBlocked ? '요청 기능 제한 중' : '주변에 요청 올리기',
                    icon: requestBlocked
                        ? Icons.block_rounded
                        : Icons.add_rounded,
                    onPressed: requestBlocked
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('현재 심부름 요청 기능이 제한되어 있습니다.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : () => context.push(AppRoutes.requestCreate),
                  ),
                  const SizedBox(height: TtmSpacing.md),
                  Text(
                    '요청은 최대 10단계로 반경을 넓혀가며 이웃을 찾아요',
                    textAlign: TextAlign.center,
                    style: TtmTypography.body.copyWith(
                      fontSize: 13,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TtmSpacing.lg),
      decoration: BoxDecoration(
        color: TtmColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TtmColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이렇게 진행돼요',
            style: TtmTypography.title.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: TtmColors.deepGreen,
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          _Step(index: 1, text: '부탁할 내용과 보상금을 입력해요'),
          const SizedBox(height: TtmSpacing.sm),
          _Step(index: 2, text: '만날 위치와 시간을 지도에서 정해요'),
          const SizedBox(height: TtmSpacing.sm),
          _Step(index: 3, text: '주변 이웃이 수락하면 바로 연결돼요'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: TtmColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: TtmSpacing.md),
        Expanded(
          child: Text(
            text,
            style: TtmTypography.body.copyWith(
              fontSize: 15,
              height: 1.4,
              color: TtmColors.deepGreen,
            ),
          ),
        ),
      ],
    );
  }
}
