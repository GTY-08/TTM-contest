import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Hashi 스타일 eyebrow 섹션 헤더.
class TtmSectionHeader extends StatelessWidget {
  const TtmSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: TtmSpacing.lg, bottom: TtmSpacing.md),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TtmTypography.eyebrow.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: isDark ? colors.primary : TtmColors.infoSlate,
              ),
              child: Text(
                actionLabel!,
                style: TtmTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? colors.primary : TtmColors.infoSlate,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
