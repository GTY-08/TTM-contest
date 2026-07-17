import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// 버튼·카드 공통 탭 스케일 피드백.
class TtmScaleTap extends StatefulWidget {
  const TtmScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = TtmMotion.cardTapScale,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<TtmScaleTap> createState() => _TtmScaleTapState();
}

class _TtmScaleTapState extends State<TtmScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: TtmMotion.instant,
          curve: TtmMotion.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
