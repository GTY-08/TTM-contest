import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// 토스·금융앱형 인증 화면 입력 필드 (흰 바탕 + 얇은 테두리 + 큰 라운드).
InputDecoration ttmAuthInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  Widget? suffix,
}) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final border = isDark ? TtmColors.darkDivider : TtmColors.lightDivider;
  final fill = scheme.surface;

  OutlineInputBorder outline([Color? c, double w = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(TtmRadius.xl),
      borderSide: BorderSide(color: c ?? border, width: w),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    labelStyle: TtmTypography.title.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    ),
    hintStyle: TtmTypography.body.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    border: outline(),
    enabledBorder: outline(),
    focusedBorder: outline(TtmColors.primary, 2),
    errorBorder: outline(scheme.error, 1.5),
    focusedErrorBorder: outline(scheme.error, 2),
  );
}

/// 인증 플로 전용 단색 CTA (그라데이션 없음).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: TtmColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: TtmColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TtmRadius.xl),
          ),
          textStyle: TtmTypography.button.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
