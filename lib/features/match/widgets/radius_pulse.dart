import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 매칭 대기 중앙 — 주변으로 퍼지는 펄스 링 (loop).
class RadiusPulse extends StatefulWidget {
  const RadiusPulse({super.key, this.size = 220, this.color});

  final double size;
  final Color? color;

  @override
  State<RadiusPulse> createState() => _RadiusPulseState();
}

class _RadiusPulseState extends State<RadiusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        widget.color ?? (isDark ? TtmColors.primaryDark : TtmColors.primary);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, child) {
          return CustomPaint(
            painter: _PulseRingsPainter(progress: _ctl.value, color: base),
            child: Center(child: child),
          );
        },
        child: Container(
          width: widget.size * 0.14,
          height: widget.size * 0.14,
          decoration: BoxDecoration(color: base, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _PulseRingsPainter extends CustomPainter {
  _PulseRingsPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _ringCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.46;

    for (var i = 0; i < _ringCount; i++) {
      final phase = (progress + i / _ringCount) % 1.0;
      final radius = maxR * phase;
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.55;
      if (opacity < 0.04) continue;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
