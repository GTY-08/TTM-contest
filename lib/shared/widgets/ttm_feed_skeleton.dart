import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// 주변 심부름 피드 로딩 placeholder (3행).
class TtmFeedSkeleton extends StatefulWidget {
  const TtmFeedSkeleton({super.key, this.rowCount = 3});

  final int rowCount;

  @override
  State<TtmFeedSkeleton> createState() => _TtmFeedSkeletonState();
}

class _TtmFeedSkeletonState extends State<TtmFeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final opacity = 0.35 + (_ctl.value * 0.25);
        return Column(
          children: [
            for (var i = 0; i < widget.rowCount; i++) ...[
              if (i > 0) const SizedBox(height: TtmSpacing.sm),
              _SkeletonRow(color: base.withValues(alpha: opacity)),
            ],
          ],
        );
      },
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.35);

    return Container(
      height: 108,
      padding: const EdgeInsets.all(TtmSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(TtmRadius.md),
        border: Border.all(color: outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 14,
            width: 180,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: TtmSpacing.sm),
          Container(
            height: 12,
            width: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(TtmRadius.sm),
            ),
          ),
        ],
      ),
    );
  }
}
