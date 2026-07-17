import 'package:flutter/material.dart';

/// 화면 진입 시 한 번만 살짝 떠오르는 페이드 + 이동 + (선택) 스케일.
class TtmFadeIn extends StatelessWidget {
  const TtmFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
    this.beginOffsetY = 16,
    this.scaleFrom = 1,
  });

  final Widget child;
  final Duration duration;
  final double beginOffsetY;

  /// 1 미만이면 살짝 커지며 등장 (예: 0.94).
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final scale = scaleFrom + (1 - scaleFrom) * t;
        Widget w = Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, beginOffsetY * (1 - t)),
            child: child,
          ),
        );
        if (scaleFrom < 1) {
          w = Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: w,
          );
        }
        return w;
      },
      child: child,
    );
  }
}
