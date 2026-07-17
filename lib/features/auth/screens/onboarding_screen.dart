import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _slides = <_SlideData>[
    _SlideData(
      title: '지금 바로\n주변 도움을 연결하세요',
      subtitle: '필요한 순간,\n가까운 사람과 빠르게 연결됩니다.',
    ),
    _SlideData(
      title: '몇 초 만에\n작업이 연결됩니다',
      subtitle: '복잡한 과정 없이\n간단하게 요청하고 해결하세요.',
    ),
    _SlideData(
      title: '안전하고\n믿을 수 있는 연결',
      subtitle: '평점과 위치 기반 시스템으로\n더 안전하게 이용할 수 있습니다.',
    ),
  ];

  final _pageController = PageController();
  int _page = 0;

  late final AnimationController _floatCtl;

  @override
  void initState() {
    super.initState();
    _floatCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _leaveOnboarding() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    final uid = ref.read(authUserIdProvider);
    context.go(uid == null ? AppRoutes.login : AppRoutes.splash);
  }

  Future<void> _goToLoginOnly() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _primaryTap() {
    if (_page >= _slides.length - 1) {
      _leaveOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    final bg = light ? const Color(0xFFFFFBF9) : TtmColors.darkBackground;
    final onBg = light ? const Color(0xFF1A1A1A) : scheme.onSurface;
    final subtle = light ? const Color(0xFF5C5C5C) : scheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TtmSpacing.lg,
                TtmSpacing.sm,
                TtmSpacing.xl,
                TtmSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (_page + 1) / _slides.length,
                        minHeight: 3,
                        backgroundColor: scheme.outlineVariant.withValues(
                          alpha: light ? 0.28 : 0.4,
                        ),
                        color: TtmColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: TtmSpacing.lg),
                  TextButton(
                    onPressed: _leaveOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: subtle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: TtmSpacing.md,
                        vertical: TtmSpacing.sm,
                      ),
                    ),
                    child: Text(
                      '나중에',
                      style: TtmTypography.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: subtle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  return _OnboardingSlideView(
                    data: _slides[index],
                    pageIndex: index,
                    onBg: onBg,
                    subtle: subtle,
                    floatAnimation: _floatCtl,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TtmSpacing.xl,
                TtmSpacing.lg,
                TtmSpacing.xl,
                TtmSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _primaryTap,
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: TtmColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TtmRadius.xl),
                        ),
                        textStyle: TtmTypography.button.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      child: Text(_page >= _slides.length - 1 ? '시작하기' : '다음'),
                    ),
                  ),
                  if (_page == _slides.length - 1) ...[
                    const SizedBox(height: TtmSpacing.md),
                    TextButton(
                      onPressed: _goToLoginOnly,
                      style: TextButton.styleFrom(
                        foregroundColor: subtle,
                        padding: const EdgeInsets.symmetric(
                          vertical: TtmSpacing.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: TtmTypography.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: subtle,
                          ),
                          children: [
                            const TextSpan(text: '이미 계정이 있나요? '),
                            TextSpan(
                              text: '로그인',
                              style: TtmTypography.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: TtmColors.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: TtmColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: TtmSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({
    required this.data,
    required this.pageIndex,
    required this.onBg,
    required this.subtle,
    required this.floatAnimation,
  });

  final _SlideData data;
  final int pageIndex;
  final Color onBg;
  final Color subtle;
  final Animation<double> floatAnimation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TtmSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TtmSpacing.sm),
          Text(
            '틈틈',
            textAlign: TextAlign.center,
            style: TtmTypography.display.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: TtmColors.primary.withValues(alpha: 0.88),
              height: 1,
            ),
          ),
          const SizedBox(height: TtmSpacing.xxxl),
          Expanded(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(pageIndex),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 560),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - t)),
                      child: _IllustrationBlock(
                        pageIndex: pageIndex,
                        floatAnimation: floatAnimation,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: TtmSpacing.xl),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TtmTypography.display.copyWith(
              fontSize: 31,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.9,
              height: 1.22,
              color: onBg,
            ),
          ),
          const SizedBox(height: TtmSpacing.lg),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TtmTypography.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: subtle,
            ),
          ),
          const SizedBox(height: TtmSpacing.xxxl),
        ],
      ),
    );
  }
}

class _IllustrationBlock extends StatelessWidget {
  const _IllustrationBlock({
    required this.pageIndex,
    required this.floatAnimation,
  });

  final int pageIndex;
  final Animation<double> floatAnimation;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width - TtmSpacing.xl * 2;
    return AnimatedBuilder(
      animation: floatAnimation,
      builder: (context, _) {
        final v = floatAnimation.value;
        return SizedBox(
          width: maxW,
          height: 210,
          child: switch (pageIndex) {
            0 => _MapScene(v: v),
            1 => _MatchScene(v: v),
            _ => _TrustScene(v: v),
          },
        );
      },
    );
  }
}

// ── Scene 1 · 지도 연결 ─────────────────────────────────────────

class _MapScene extends StatelessWidget {
  const _MapScene({required this.v});
  final double v;

  @override
  Widget build(BuildContext context) {
    final dy1 = (v - 0.5) * 14;
    final dy2 = (0.5 - v) * 12;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF5EE), Color(0xFFD6EDE1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Positioned.fill(child: CustomPaint(painter: _DashedArcPainter())),
            // Floating errand card (top center)
            Positioned(
              top: 14 + dy1 * 0.4,
              left: 0,
              right: 0,
              child: Center(
                child: _FloatingCard(
                  icon: Icons.shopping_bag_rounded,
                  label: '배달·운반',
                  amount: '₩3,000',
                ),
              ),
            ),
            // Requester avatar (left, float phase 1)
            Positioned(
              left: 20,
              bottom: 32 + dy1,
              child: _AvatarPin(
                color: const Color(0xFFF5A623),
                icon: Icons.person_rounded,
                tag: '요청자',
              ),
            ),
            // Helper map pin (right, float phase 2)
            Positioned(
              right: 20,
              top: 36 + dy2,
              child: const _MapPinAvatar(tag: '작업자'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.icon,
    required this.label,
    required this.amount,
  });
  final IconData icon;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: TtmColors.deepGreen.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: TtmColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: TtmColors.deepGreen),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF263331),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: Color(0xFFB0BAB8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: TtmColors.deepGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPin extends StatelessWidget {
  const _AvatarPin({
    required this.color,
    required this.icon,
    required this.tag,
  });
  final Color color;
  final IconData icon;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 26, color: Colors.white),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TtmColors.deepGreen,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPinAvatar extends StatelessWidget {
  const _MapPinAvatar({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(Icons.location_on, size: 64, color: TtmColors.primary),
            Positioned(
              top: 11,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: TtmColors.deepGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            '도움이',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TtmColors.deepGreen,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Scene 2 · 빠른 매칭 ─────────────────────────────────────────

class _MatchScene extends StatelessWidget {
  const _MatchScene({required this.v});
  final double v;

  @override
  Widget build(BuildContext context) {
    final dy1 = (v - 0.5) * 12;
    final dy2 = (0.5 - v) * 12;
    final pulse = 0.85 + v * 0.3;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFDF8), Color(0xFFEFF6EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: TtmColors.primaryLight.withValues(alpha: 0.8),
        ),
      ),
      child: Stack(
        children: [
          // Speed badge
          Positioned(
            top: 12,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: TtmColors.primaryLight,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 13,
                    color: TtmColors.deepGreen,
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    '방금 매칭 · 8초',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: TtmColors.deepGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Cards + connector row (Positioned.fill prevents overflow on narrow screens)
          Positioned.fill(
            top: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(0, dy1),
                        child: const _RequestCard(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(scale: pulse, child: _BoltConnector()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(0, dy2),
                        child: const _MatchCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TtmColors.deepGreen.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: TtmColors.primaryLight,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              '구매',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: TtmColors.deepGreen,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAEA),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            height: 8,
            width: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAEA),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '₩3,500',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: TtmColors.deepGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoltConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: TtmColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: TtmColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TtmColors.deepGreen.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [TtmColors.primary, TtmColors.deepGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 7,
            width: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAEA),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                size: 12,
                color: TtmColors.premiumGold,
              ),
              const SizedBox(width: 2),
              const Text(
                '4.9',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: TtmColors.primaryLight,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              '매칭 완료',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TtmColors.deepGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scene 3 · 안전 신뢰 ─────────────────────────────────────────

class _TrustScene extends StatelessWidget {
  const _TrustScene({required this.v});
  final double v;

  @override
  Widget build(BuildContext context) {
    final dy = (v - 0.5) * 14;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF5EE), Color(0xFFD6EDE1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DottedCirclePainter()),
            ),
            // Shield icon (center, gentle float)
            Transform.translate(
              offset: Offset(0, dy * 0.4),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: TtmColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: TtmColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            // 활동 이력 chip (left, float phase 1)
            Positioned(
              left: 18,
              top: 30 + dy,
              child: const _TrustChip(
                icon: Icons.history_rounded,
                label: '활동 이력',
              ),
            ),
            // 평점 chip (right, float phase 2)
            Positioned(
              right: 18,
              top: 48 - dy,
              child: const _TrustChip(
                icon: Icons.star_rounded,
                label: '평점 4.9',
              ),
            ),
            // 안전 매칭 chip (bottom, gentle float)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18 + dy * 0.3,
              child: Center(
                child: const _TrustChip(
                  icon: Icons.handshake_outlined,
                  label: '안전 매칭',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: TtmColors.deepGreen.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TtmColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: TtmColors.deepGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom painters ─────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TtmColors.deepGreen.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TtmColors.deepGreen.withValues(alpha: 0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.7)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.22,
        size.width * 0.65,
        size.height * 0.22,
        size.width * 0.75,
        size.height * 0.32,
      );

    const dashLen = 5.0;
    const gapLen = 8.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        final end = math.min(dist + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DottedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TtmColors.deepGreen.withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final r in [48.0, 78.0, 108.0]) {
      _drawDashedCircle(canvas, Offset(cx, cy), r, paint);
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const dashAngle = 0.18;
    const gapAngle = 0.24;
    double angle = 0;
    while (angle < math.pi * 2) {
      final end = math.min(angle + dashAngle, math.pi * 2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        end - angle,
        false,
        paint,
      );
      angle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
