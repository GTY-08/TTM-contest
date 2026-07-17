import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 설정 탭용 선택 칩 (요청 생성 화면과 동일 톤).
class SettingsChoiceChip extends StatelessWidget {
  const SettingsChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filled = isDark ? TtmColors.primaryDark : TtmColors.primary;
    final neutralBg = isDark
        ? TtmColors.darkSurfaceAlt
        : TtmColors.lightSurfaceAlt;
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(TtmRadius.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: TtmSpacing.lg,
            vertical: TtmSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? filled : neutralBg,
            borderRadius: BorderRadius.circular(TtmRadius.lg),
            border: Border.all(
              color: selected
                  ? filled
                  : colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TtmTypography.title.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : colors.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TtmTypography.body.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
