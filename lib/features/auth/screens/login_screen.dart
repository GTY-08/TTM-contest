import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../auth_error_message.dart';

/// 이메일·Supabase OAuth(카카오·구글). Apple은 iOS 네이티브 설정 후 연동 예정.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _kakaoBusy = false;
  bool _googleBusy = false;

  void _showSoonToast(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$name은 준비 중이에요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _signInKakao() async {
    if (_kakaoBusy) return;
    setState(() => _kakaoBusy = true);
    try {
      final ok = await ref.read(authRepositoryProvider).signInWithKakaoOAuth();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('카카오 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(describeAuthError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _kakaoBusy = false);
    }
  }

  Future<void> _signInGoogle() async {
    if (_googleBusy) return;
    setState(() => _googleBusy = true);
    try {
      final ok = await ref.read(authRepositoryProvider).signInWithGoogleOAuth();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Google 페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(describeAuthError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.brightness == Brightness.dark
        ? scheme.surface
        : TtmColors.lightSurface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: TtmSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.06),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/ttm_symbol.svg',
                          width: 44,
                          height: 44,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '틈틈',
                          textAlign: TextAlign.center,
                          style: TtmTypography.display.copyWith(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            height: 1,
                            color: TtmColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TtmSpacing.xl),
                    Text(
                      '틈틈 계정으로\n주변 심부름을 시작하세요',
                      textAlign: TextAlign.center,
                      style: TtmTypography.display.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.25,
                        color: scheme.onSurface,
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.07),
                    SizedBox(
                      height: 58,
                      child: FilledButton(
                        onPressed: () => context.push(AppRoutes.emailSignUp),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          backgroundColor: TtmColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TtmRadius.xl),
                          ),
                          textStyle: TtmTypography.button.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        child: const Text('틈틈 계정 생성'),
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.md),
                    SizedBox(
                      height: 58,
                      child: OutlinedButton(
                        onPressed: () => context.push(AppRoutes.emailLogin),
                        style: OutlinedButton.styleFrom(
                          elevation: 0,
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.9),
                            width: 1.25,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TtmRadius.xl),
                          ),
                          textStyle: TtmTypography.button.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('기존 계정 로그인'),
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.md),
                    Text(
                      '아이디 생성 · 이메일 확인 · 프로필 설정까지 한 번에 이어져요',
                      textAlign: TextAlign.center,
                      style: TtmTypography.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.xxxl),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TtmSpacing.lg,
                          ),
                          child: Text(
                            '또는',
                            style: TtmTypography.body.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TtmSpacing.lg),
                    _SocialRow(
                      height: 54,
                      label: '카카오',
                      busy: _kakaoBusy,
                      background: const Color(0xFFFEE500),
                      foreground: const Color(0xFF191919),
                      leading: SvgPicture.asset(
                        'assets/icons/social_kakao.svg',
                        width: 22,
                        height: 22,
                      ),
                      onTap: _signInKakao,
                    ),
                    const SizedBox(height: TtmSpacing.sm + 2),
                    _SocialRow(
                      height: 54,
                      label: 'Google',
                      busy: _googleBusy,
                      background: scheme.surface,
                      foreground: scheme.onSurface,
                      outlineSide: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.85),
                        width: 1.2,
                      ),
                      leading: SvgPicture.asset(
                        'assets/icons/social_google.svg',
                        width: 22,
                        height: 22,
                      ),
                      onTap: _signInGoogle,
                    ),
                    const SizedBox(height: TtmSpacing.sm + 2),
                    _SocialRow(
                      height: 54,
                      label: 'Apple',
                      busy: false,
                      background: const Color(0xFF000000),
                      foreground: Colors.white,
                      leading: SvgPicture.asset(
                        'assets/icons/social_apple.svg',
                        width: 22,
                        height: 22,
                      ),
                      onTap: () async {
                        _showSoonToast(context, 'Apple');
                      },
                    ),
                    const SizedBox(height: TtmSpacing.xxxl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialRow extends StatefulWidget {
  const _SocialRow({
    required this.height,
    required this.label,
    required this.busy,
    required this.background,
    required this.foreground,
    required this.leading,
    required this.onTap,
    this.outlineSide,
  });

  final double height;
  final String label;
  final bool busy;
  final Color background;
  final Color foreground;
  final Widget leading;
  final Future<void> Function() onTap;
  final BorderSide? outlineSide;

  @override
  State<_SocialRow> createState() => _SocialRowState();
}

class _SocialRowState extends State<_SocialRow> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TtmRadius.xl);
    return Listener(
      onPointerDown: (_) => setState(() => _scale = 0.98),
      onPointerUp: (_) => setState(() => _scale = 1),
      onPointerCancel: (_) => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: widget.busy ? 0.55 : 1,
          child: Material(
            color: widget.background,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side:
                  widget.outlineSide ??
                  const BorderSide(color: Colors.transparent),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.busy ? null : () => widget.onTap(),
              customBorder: RoundedRectangleBorder(borderRadius: radius),
              child: SizedBox(
                height: widget.height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TtmSpacing.lg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      widget.leading,
                      const SizedBox(width: 10),
                      Text(
                        widget.label,
                        style: TtmTypography.button.copyWith(
                          color: widget.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
