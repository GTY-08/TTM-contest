import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';

/// 10단계 반경 확장을 시각화하는 가는 progress bar.
///
/// 각 단계마다 한 칸씩 차오르고, 현재 진행 중인 단계는 살짝 빛난다.
/// "80% 절제" 원칙에 따라 한 줄짜리 얇은 인디케이터로만 둔다(반경 확장 은유).
class StageProgressBar extends StatelessWidget {
  const StageProgressBar({
    super.key,
    required this.currentStage,
    this.totalStages = 10,
  });

  final int currentStage;
  final int totalStages;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filled = isDark ? TtmColors.primaryDark : TtmColors.primary;
    final track = isDark ? TtmColors.darkDivider : TtmColors.lightDivider;

    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (int i = 1; i <= totalStages; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: TtmMotion.standard,
                curve: TtmMotion.easeOut,
                decoration: BoxDecoration(
                  color: i <= currentStage ? filled : track,
                  borderRadius: BorderRadius.circular(TtmRadius.pill),
                  boxShadow: i == currentStage && i > 0
                      ? [
                          BoxShadow(
                            color: filled.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 0),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            if (i < totalStages) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}
