import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 가입 마무리 등 단계형 플로우 상단 진행 표시 (세그먼트 바 + 짧은 라벨).
class AuthStepProgress extends StatelessWidget {
  const AuthStepProgress({
    super.key,
    required this.current,
    required this.total,
    this.label,
  }) : assert(total >= 1),
       assert(current >= 1 && current <= total);

  /// 1-based 현재 단계.
  final int current;

  final int total;

  /// 예: `본인 확인` — 없으면 `2/3` 만 표시.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = scheme.outlineVariant.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(total, (i) {
            final done = i < current;
            final flex = 1;
            return Expanded(
              flex: flex,
              child: Padding(
                padding: EdgeInsets.only(
                  right: i < total - 1 ? TtmSpacing.sm : 0,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  height: 4,
                  decoration: BoxDecoration(
                    color: done ? TtmColors.primary : track,
                    borderRadius: BorderRadius.circular(TtmRadius.pill),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: TtmSpacing.md),
        Row(
          children: [
            if (label != null && label!.isNotEmpty)
              Expanded(
                child: Text(
                  label!,
                  style: TtmTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              )
            else
              const Spacer(),
            Text(
              '$current / $total',
              style: TtmTypography.title.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
