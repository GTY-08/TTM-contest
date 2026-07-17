import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/ttm_surface_style.dart';

/// 설정·프로필 화면용 iOS형 그룹 카드.
class TtmSettingsGroup extends StatelessWidget {
  const TtmSettingsGroup({
    super.key,
    this.sectionTitle,
    required this.children,
  });

  final String? sectionTitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: TtmSpacing.lg,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
        );
      }
      items.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sectionTitle != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: TtmSpacing.sm,
              bottom: TtmSpacing.sm,
            ),
            child: Text(
              sectionTitle!.toUpperCase(),
              style: TtmTypography.eyebrow.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        Builder(
          builder: (context) {
            final surface = TtmSurfaceStyle.of(context);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(TtmRadius.card),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                ),
                boxShadow: surface.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TtmRadius.card),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: surface.cardSheenGradient,
                        ),
                      ),
                    ),
                    Column(children: items),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 설정 행. 탭 시 scale 0.98 / 100ms.
class TtmSettingsTile extends StatefulWidget {
  const TtmSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;

  @override
  State<TtmSettingsTile> createState() => _TtmSettingsTileState();
}

class _TtmSettingsTileState extends State<TtmSettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canTap = widget.enabled && widget.onTap != null;
    final trailing =
        widget.trailing ??
        (widget.showChevron && canTap
            ? Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
                size: 22,
              )
            : null);

    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TtmSpacing.lg,
          vertical: TtmSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TtmTypography.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.enabled
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      style: TtmTypography.body.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: TtmSpacing.sm),
              trailing,
            ],
          ],
        ),
      ),
    );

    if (!canTap) {
      return Opacity(opacity: widget.enabled ? 1 : 0.55, child: row);
    }

    return Material(
      color: Colors.transparent,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1,
            duration: TtmMotion.instant,
            curve: TtmMotion.easeOut,
            child: row,
          ),
        ),
      ),
    );
  }
}

/// 탭 상단 안내 배너.
class TtmSettingsInfoBanner extends StatelessWidget {
  const TtmSettingsInfoBanner({
    super.key,
    required this.title,
    required this.body,
    this.icon,
  });

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? TtmColors.primary.withValues(alpha: 0.15)
        : TtmColors.primaryLight;
    final titleColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : TtmColors.deepGreen;
    final effectiveIcon = icon ?? Icons.info_outline_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TtmSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TtmRadius.card),
        border: Border.all(
          color: TtmColors.primary.withValues(alpha: isDark ? 0.3 : 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(effectiveIcon, size: 20, color: TtmColors.primary),
          const SizedBox(width: TtmSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TtmTypography.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TtmTypography.body.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : TtmColors.deepGreen.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
