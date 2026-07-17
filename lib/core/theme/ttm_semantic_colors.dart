import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'dashboard_colors.dart';

/// 상태(성공/정보/경고) + Tier accent 시맨틱 색 토큰.
///
/// - Accent(코랄)은 오류/위험에만 쓰고, 나머지는 이 확장을 쓴다.
/// - [missionAccent]: LIVE·활동 ON·FAB·Primary CTA (다크=라임, 라이트=청록).
/// - [brandTeal]: 제목·링크 (다크 본문 강조, 라이트=primary).
@immutable
class TtmSemanticColors extends ThemeExtension<TtmSemanticColors> {
  const TtmSemanticColors({
    required this.success,
    required this.successContainer,
    required this.info,
    required this.infoContainer,
    required this.warning,
    required this.warningContainer,
    required this.missionAccent,
    required this.brandTeal,
    required this.onMissionAccent,
  });

  final Color success;
  final Color successContainer;
  final Color info;
  final Color infoContainer;
  final Color warning;
  final Color warningContainer;
  final Color missionAccent;
  final Color brandTeal;
  final Color onMissionAccent;

  static TtmSemanticColors light() {
    return TtmSemanticColors(
      success: TtmColors.success,
      successContainer: TtmColors.success.withValues(alpha: 0.12),
      info: TtmColors.info,
      infoContainer: TtmColors.info.withValues(alpha: 0.12),
      warning: TtmColors.warning,
      warningContainer: TtmColors.warning.withValues(alpha: 0.12),
      missionAccent: TtmColors.primary,
      brandTeal: TtmColors.primary,
      onMissionAccent: Colors.white,
    );
  }

  static TtmSemanticColors dark() {
    return TtmSemanticColors(
      success: TtmColors.primaryDark,
      successContainer: TtmColors.primaryDark.withValues(alpha: 0.18),
      info: TtmColors.primaryDark,
      infoContainer: TtmColors.primaryDark.withValues(alpha: 0.16),
      warning: const Color(0xFFFBBF24),
      warningContainer: const Color(0xFFFBBF24).withValues(alpha: 0.18),
      missionAccent: TtmDashboardColors.accent,
      brandTeal: TtmColors.primaryDark,
      onMissionAccent: TtmDashboardColors.onAccent,
    );
  }

  /// 수행자 대시보드 다크 — [dark]와 동일 accent 규칙.
  static TtmSemanticColors dashboard() => dark();

  static TtmSemanticColors of(BuildContext context) {
    final ext = Theme.of(context).extension<TtmSemanticColors>();
    assert(ext != null, 'TtmSemanticColors가 ThemeData.extensions에 없습니다.');
    return ext!;
  }

  @override
  TtmSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? info,
    Color? infoContainer,
    Color? warning,
    Color? warningContainer,
    Color? missionAccent,
    Color? brandTeal,
    Color? onMissionAccent,
  }) {
    return TtmSemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      missionAccent: missionAccent ?? this.missionAccent,
      brandTeal: brandTeal ?? this.brandTeal,
      onMissionAccent: onMissionAccent ?? this.onMissionAccent,
    );
  }

  @override
  TtmSemanticColors lerp(ThemeExtension<TtmSemanticColors>? other, double t) {
    if (other is! TtmSemanticColors) return this;
    return t < 0.5 ? this : other;
  }
}
