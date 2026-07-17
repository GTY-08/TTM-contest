import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../auth/theme/auth_field_style.dart';

/// 로그인 상태에서 앱 내 비밀번호 변경.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
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
          const SnackBar(
            content: Text('비밀번호를 변경했어요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
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
      appBar: AppBar(title: const Text('비밀번호 변경'), scrolledUnderElevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(TtmSpacing.xl),
        children: [
          Text(
            '새 비밀번호를 입력해 주세요',
            style: TtmTypography.title.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: TtmSpacing.xl),
          TextField(
            controller: _pw1,
            obscureText: !_show,
            decoration: ttmAuthInputDecoration(
              context,
              label: '새 비밀번호',
              suffix: IconButton(
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          TextField(
            controller: _pw2,
            obscureText: !_show,
            decoration: ttmAuthInputDecoration(context, label: '새 비밀번호 확인'),
          ),
          if (_error != null) ...[
            const SizedBox(height: TtmSpacing.md),
            Text(
              _error!,
              style: TtmTypography.body.copyWith(
                color: TtmColors.accent,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: TtmSpacing.xxl),
          TTMButton(
            label: '변경하기',
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
