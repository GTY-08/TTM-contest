import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/ttm_surface_style.dart';

class TtmOpsNavDestination {
  const TtmOpsNavDestination({
    required this.label,
    this.icon,
    this.iconWidget,
    this.selectedIconWidget,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final Widget? selectedIconWidget;
}

/// 운영형 5탭 하단 네비.
class TtmOpsBottomNav extends StatelessWidget {
  const TtmOpsBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<TtmOpsNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final navShadow = TtmSurfaceStyle.of(context).navBarShadow;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
        boxShadow: navShadow,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : TtmSpacing.sm),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _Item(
                  data: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final TtmOpsNavDestination data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TtmMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: TtmSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: TtmMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(TtmRadius.pill),
              ),
              child: data.iconWidget != null
                  ? IconTheme(
                      data: IconThemeData(color: color, size: 22),
                      child: data.iconWidget!,
                    )
                  : Icon(data.icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: TtmTypography.label.copyWith(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
