import 'package:flutter/material.dart';

/// online·진행 상태용 펄스 점 (loop 1개).
class TtmLiveDot extends StatefulWidget {
  const TtmLiveDot({super.key, this.size = 8, this.color});

  final double size;
  final Color? color;

  @override
  State<TtmLiveDot> createState() => _TtmLiveDotState();
}

class _TtmLiveDotState extends State<TtmLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, child) {
        final t = _ctl.value;
        final glow = 4 + (4 * (1 - (t - 0.5).abs() * 2));
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.35),
                blurRadius: glow,
                spreadRadius: glow * 0.15,
              ),
            ],
          ),
        );
      },
    );
  }
}
