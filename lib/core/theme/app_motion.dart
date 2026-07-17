import 'package:flutter/animation.dart';

/// 디자인 2차 — 애니메이션 상수 (Lottie 없음, 동시 1~2개 제한).
abstract final class TtmMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutBack;

  static const double tapScale = 0.97;
  static const double cardTapScale = 0.98;
}
