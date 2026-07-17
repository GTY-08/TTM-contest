import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 플로팅 글래스 하단 네비 — iOS 부드러움 + Material 선택 피드백.
class TtmGlassBottomNav extends StatelessWidget {
  const TtmGlassBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<TtmNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        0,
        TtmSpacing.lg,
        bottom > 0 ? bottom : TtmSpacing.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TtmRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: isDark ? 0.82 : 0.88),
              borderRadius: BorderRadius.circular(TtmRadius.pill),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TtmSpacing.sm,
                vertical: TtmSpacing.sm,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        data: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TtmNavDestination {
  const TtmNavDestination({
    required this.label,
    this.icon,
    this.selectedIcon,
    this.iconWidget,
    this.selectedIconWidget,
  });

  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
  final Widget? iconWidget;
  final Widget? selectedIconWidget;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final TtmNavDestination data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TtmRadius.pill),
        splashColor: colors.primary.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: TtmMotion.fast,
          curve: TtmMotion.easeOut,
          padding: const EdgeInsets.symmetric(vertical: TtmSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(TtmRadius.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: TtmMotion.instant,
                child: selected
                    ? (data.selectedIconWidget ??
                          Icon(
                            data.selectedIcon ?? data.icon,
                            key: const ValueKey('sel'),
                            size: 22,
                            color: colors.primary,
                          ))
                    : (data.iconWidget ??
                          Icon(
                            data.icon,
                            key: const ValueKey('unsel'),
                            size: 22,
                            color: colors.onSurfaceVariant,
                          )),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: TtmTypography.label.copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
