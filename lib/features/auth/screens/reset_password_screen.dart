import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_fade_in.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final a = _pw1.text;
    final b = _pw2.text;

    if (a.length < 8) {
      setState(() => _error = '비밀번호는 8자 이상으로 설정해 주세요.');
      return;
    }
    if (a != b) {
      setState(() => _error = '비밀번호가 서로 달라요.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: a),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('비밀번호를 변경했어요. 다시 로그인해 주세요.')),
        );

      // 보안상 재로그인을 유도한다.
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '비밀번호 변경에 실패했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 재설정')),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              TtmColors.primaryLight.withValues(alpha: 0.4),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: TtmFadeIn(
            duration: const Duration(milliseconds: 560),
            beginOffsetY: 22,
            scaleFrom: 0.93,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: TtmSpacing.xl,
                vertical: TtmSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '새 비밀번호를 설정해요',
                    style: TtmTypography.display.copyWith(
                      color: colors.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                  Text(
                    '안전한 계정 보호를 위해 8자 이상으로 설정해 주세요.',
                    style: TtmTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.xl),
                  TextField(
                    controller: _pw1,
                    obscureText: !_show,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: '새 비밀번호',
                      hintText: '8자 이상',
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _show
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 22,
                          color: colors.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.md),
                  TextField(
                    controller: _pw2,
                    obscureText: !_show,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: '새 비밀번호 확인',
                      hintText: '한 번 더 입력',
                      labelStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: TtmSpacing.md),
                    Text(
                      _error!,
                      style: TtmTypography.body.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: TtmSpacing.xl),
                  TTMButton(
                    label: '비밀번호 변경',
                    onPressed: _busy ? null : _submit,
                    busy: _busy,
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
