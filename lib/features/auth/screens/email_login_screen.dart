import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ttm_fade_in.dart';
import '../auth_error_message.dart';
import '../controllers/auth_controller.dart';
import '../theme/auth_field_style.dart';

/// 이메일 로그인 (미니멀 · 흰 바탕).
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final controller = ref.read(authControllerProvider.notifier);

    try {
      await controller.signInWithEmail(
        email: _emailCtl.text.trim(),
        password: _passwordCtl.text,
      );
    } catch (e) {
      _toast(describeAuthError(e));
    }
  }

  Future<void> _sendReset() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      _toast('이메일을 입력해 주세요.');
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    try {
      await controller.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _toast('재설정 메일을 보냈어요.');
    } catch (e) {
      _toast(describeAuthError(e));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(authControllerProvider).isLoading;
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
                    '틈틈 계정 로그인',
                    style: TtmTypography.display.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.15,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.xxxl),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : _sendReset,
                      child: Text(
                        '비밀번호 재설정',
                        style: TtmTypography.title.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TtmColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.xl),
                  AuthPrimaryButton(
                    label: '로그인',
                    onPressed: busy ? null : _submit,
                    busy: busy,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
