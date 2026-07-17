import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// 매칭 진행 화면 — 내 역할(요청자/작업자) 표시.
class MatchRoleBadge extends StatelessWidget {
  const MatchRoleBadge({
    super.key,
    required this.isRequester,
    this.compact = false,
  });

  final bool isRequester;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = isRequester ? '요청자' : '작업자';
    final bg = isRequester
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final fg = isRequester ? colors.primary : colors.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TtmRadius.sm),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TtmTypography.label.copyWith(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
