import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/ttm_fade_in.dart';
import '../auth_error_message.dart';
import '../controllers/auth_controller.dart';
import '../theme/auth_field_style.dart';

/// 이메일 회원가입.
class EmailSignUpScreen extends ConsumerStatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  ConsumerState<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends ConsumerState<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _otpCtl = TextEditingController();
  bool _showPassword = false;

  bool _resendBusy = false;
  bool _emailVerificationPending = false;
  String? _pendingEmail;
  Timer? _resendCooldownTimer;
  int _resendCooldownSeconds = 0;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _otpCtl.dispose();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final controller = ref.read(authControllerProvider.notifier);
    try {
      final outcome = await controller.signUpWithEmail(
        email: _emailCtl.text.trim(),
        password: _passwordCtl.text,
      );
      if (!mounted) return;
      if (outcome.emailConfirmationPending) {
        setState(() {
          _pendingEmail = _emailCtl.text.trim();
          _emailVerificationPending = true;
          _otpCtl.clear();
        });
        _startResendCooldown();
        _toast('인증번호가 담긴 메일을 보냈어요. 메일의 8자리 코드를 입력해 주세요.');
      } else {
        _toast(
          '가입이 완료됐어요. (이메일 확인 없이 로그인된 상태예요. '
          '메일이 안 와도 정상일 수 있어요.)',
        );
      }
    } catch (e) {
      _toast(describeAuthError(e));
    }
  }

  Future<void> _verifyEmailOtp() async {
    final email = (_pendingEmail ?? _emailCtl.text).trim();
    final token = _otpCtl.text.trim().replaceAll(RegExp(r'\s+'), '');
    final controller = ref.read(authControllerProvider.notifier);
    try {
      await controller.verifySignupEmailOtp(email: email, token: token);
      if (!mounted) return;
      _toast('이메일 인증이 완료됐어요.');
    } catch (e) {
      if (!mounted) return;
      _toast(describeAuthError(e));
    }
  }

  Future<void> _resendConfirmation() async {
    if (_resendCooldownSeconds > 0) {
      _toast('인증번호는 $_resendCooldownSeconds초 뒤에 다시 받을 수 있어요.');
      return;
    }
    final email = (_pendingEmail ?? _emailCtl.text).trim();
    if (email.isEmpty) {
      _toast('이메일을 입력해 주세요.');
      return;
    }
    setState(() => _resendBusy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendSignupConfirmationEmail(email);
      if (!mounted) return;
      _toast(
        '인증번호를 다시 보냈어요. 메일이 안 보이면 스팸함을 확인하고, '
        '같은 주소로 너무 자주 누르면 몇 분 뒤에 다시 시도해 주세요.',
      );
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      _toast(describeAuthError(e));
    } finally {
      if (mounted) setState(() => _resendBusy = false);
    }
  }

  void _editEmail() {
    setState(() {
      _emailVerificationPending = false;
      _pendingEmail = null;
      _otpCtl.clear();
    });
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = 60);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
        return;
      }
      setState(() => _resendCooldownSeconds -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(authControllerProvider).isLoading;
    final resendLocked = busy || _resendBusy || _resendCooldownSeconds > 0;
    final isOtpStep = _emailVerificationPending;
    final bg = scheme.brightness == Brightness.dark
        ? scheme.surface
        : TtmColors.lightSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
      ),
      body: SafeArea(
        child: TtmFadeIn(
          duration: const Duration(milliseconds: 320),
          beginOffsetY: 12,
          scaleFrom: 0.99,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.xl,
              TtmSpacing.sm,
              TtmSpacing.xl,
              TtmSpacing.xxxl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isOtpStep ? '이메일 인증' : '틈틈 계정 만들기',
                    style: TtmTypography.display.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.15,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.md),
                  Text(
                    isOtpStep
                        ? '메일에 있는 인증번호를 앱에 입력하면 계정 생성이 완료됩니다.'
                        : '로그인에 사용할 아이디를 만들고 이메일을 확인해 주세요.',
                    style: TtmTypography.body.copyWith(
                      fontSize: 15,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.lg),
                  _AccountSetupPreview(),
                  const SizedBox(height: TtmSpacing.xxxl),
                  if (isOtpStep) ...[
                    _EmailOtpVerificationPanel(
                      email: _pendingEmail ?? _emailCtl.text.trim(),
                      controller: _otpCtl,
                      busy: busy,
                      resendBusy: _resendBusy,
                      resendCooldownSeconds: _resendCooldownSeconds,
                      onVerify: _verifyEmailOtp,
                      onResend: resendLocked ? null : _resendConfirmation,
                      onEditEmail: busy ? null : _editEmail,
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TtmTypography.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      decoration: ttmAuthInputDecoration(
                        context,
                        label: '틈틈 아이디',
                        hint: 'name@email.com',
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (!s.contains('@') || !s.contains('.')) {
                          return '형식을 확인해 주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: TtmSpacing.lg),
                    TextFormField(
                      controller: _passwordCtl,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TtmTypography.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      decoration: ttmAuthInputDecoration(
                        context,
                        label: '계정 비밀번호',
                        hint: '8자 이상',
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 22,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.length < 8) return '8자 이상';
                        return null;
                      },
                    ),
                    const SizedBox(height: TtmSpacing.xl),
                    AuthPrimaryButton(
                      label: '아이디 생성',
                      onPressed: busy ? null : _submit,
                      busy: busy,
                    ),
                    const SizedBox(height: TtmSpacing.lg),
                    TextButton(
                      onPressed: resendLocked ? null : _resendConfirmation,
                      child: Text(
                        _resendBusy
                            ? '보내는 중…'
                            : _resendCooldownSeconds > 0
                            ? '$_resendCooldownSeconds초 뒤 다시 받기'
                            : '인증 메일 다시 받기',
                        style: TtmTypography.title.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TtmColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailOtpVerificationPanel extends StatelessWidget {
  const _EmailOtpVerificationPanel({
    required this.email,
    required this.controller,
    required this.busy,
    required this.resendBusy,
    required this.resendCooldownSeconds,
    required this.onVerify,
    required this.onResend,
    required this.onEditEmail,
  });

  final String email;
  final TextEditingController controller;
  final bool busy;
  final bool resendBusy;
  final int resendCooldownSeconds;
  final VoidCallback onVerify;
  final VoidCallback? onResend;
  final VoidCallback? onEditEmail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(TtmSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                email,
                style: TtmTypography.title.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: TtmSpacing.xs),
              Text(
                '메일에 표시된 인증번호 8자리를 입력해 주세요. 메일 안의 버튼은 사용하지 않습니다.',
                style: TtmTypography.body.copyWith(
                  fontSize: 14,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TtmSpacing.lg),
              TextField(
                controller: controller,
                enabled: !busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 8,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                style: TtmTypography.display.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                  color: scheme.onSurface,
                ),
                decoration: ttmAuthInputDecoration(
                  context,
                  label: '인증번호',
                  hint: '8자리 숫자',
                ).copyWith(counterText: ''),
                onSubmitted: (_) {
                  if (!busy) onVerify();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: TtmSpacing.xl),
        AuthPrimaryButton(
          label: '인증 완료',
          onPressed: busy ? null : onVerify,
          busy: busy,
        ),
        const SizedBox(height: TtmSpacing.md),
        TextButton(
          onPressed: onResend,
          child: Text(
            resendBusy
                ? '보내는 중…'
                : resendCooldownSeconds > 0
                ? '$resendCooldownSeconds초 뒤 다시 받기'
                : '인증번호 다시 받기',
            style: TtmTypography.title.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: TtmColors.primary,
            ),
          ),
        ),
        TextButton(
          onPressed: onEditEmail,
          child: Text(
            '이메일 다시 입력',
            style: TtmTypography.title.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountSetupPreview extends StatelessWidget {
  const _AccountSetupPreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (Icons.alternate_email_rounded, '아이디 생성'),
      (Icons.mark_email_read_outlined, '이메일 확인'),
      (Icons.person_outline_rounded, '프로필 설정'),
    ];
    return Container(
      padding: const EdgeInsets.all(TtmSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].$1, size: 22, color: TtmColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    style: TtmTypography.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ],
      ),
    );
  }
}
