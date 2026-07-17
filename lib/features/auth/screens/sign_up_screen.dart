import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../auth_error_message.dart';
import '../theme/auth_field_style.dart';
import '../widgets/signup_step_done_flash.dart';

/// 대회용 계정 생성 마무리 화면.
///
/// 별도 확인 단계 없이 닉네임을 저장한다.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();

  bool _marketingOptIn = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final nickname = _nicknameController.text.trim();
      final repository = ref.read(userRepositoryProvider);
      if (!await repository.isNicknameAvailable(nickname)) {
        if (!mounted) return;
        setState(() => _error = '이미 사용 중인 닉네임이에요.');
        return;
      }

      await repository.completeOnboarding(
        nickname: nickname,
        marketingOptIn: _marketingOptIn,
      );
      if (!mounted) return;
      await showSignupStepDoneFlash(context, title: '가입 완료');
      ref.invalidate(myProfileProvider);
    } catch (error) {
      if (mounted) setState(() => _error = describeAuthError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = colors.brightness == Brightness.dark
        ? colors.surface
        : TtmColors.lightSurface;
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        scrolledUnderElevation: 0,
        title: Text(
          '계정 만들기',
          style: TtmTypography.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('프로필을 불러오지 못했어요.')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('로그인 정보가 없어요.'));
          }
          if (profile.isProfileComplete) {
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                TtmSpacing.xl,
                TtmSpacing.xl,
                TtmSpacing.xl,
                TtmSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '틈틈에서 사용할\n이름을 정해 주세요',
                      style: TtmTypography.display.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.md),
                    Text(
                      '요청자와 작업자 모두 같은 계정으로 이용할 수 있어요.',
                      style: TtmTypography.body.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.xxl),
                    TextFormField(
                      controller: _nicknameController,
                      enabled: !_submitting,
                      maxLength: 12,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: ttmAuthInputDecoration(
                        context,
                        label: '닉네임',
                        hint: '2~12자로 입력',
                      ),
                      validator: (value) {
                        final nickname = value?.trim() ?? '';
                        if (nickname.length < 2 || nickname.length > 12) {
                          return '닉네임은 2~12자로 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: TtmSpacing.lg),
                    _AgreementRow(
                      value: _marketingOptIn,
                      label: '혜택 및 소식 알림 동의 (선택)',
                      onChanged: (value) =>
                          setState(() => _marketingOptIn = value),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: TtmSpacing.md),
                      Text(
                        _error!,
                        style: TtmTypography.body.copyWith(color: colors.error),
                      ),
                    ],
                    const SizedBox(height: TtmSpacing.xl),
                    AuthPrimaryButton(
                      label: '틈틈 시작하기',
                      busy: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: (next) => onChanged(next ?? false)),
        Expanded(
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: TtmSpacing.sm),
              child: Text(label, style: TtmTypography.body),
            ),
          ),
        ),
      ],
    );
  }
}
