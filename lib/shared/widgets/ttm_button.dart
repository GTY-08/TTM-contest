import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/ttm_surface_style.dart';

/// 디자인 시스템 §5-1의 4가지 버튼 변형.
///
/// - [primary]    : 메인 CTA (Primary 그라데이션 + 은은한 그림자)
/// - [secondary]  : 보조 CTA (Primary Light 배경 + Primary 텍스트)
/// - [ghost]      : 테두리만 있는 Primary. 취소 등 부정적 액션 기본값.
/// - [danger]     : 진짜 돌이킬 수 없는 액션(신고/탈퇴)에만 사용.
enum TtmButtonVariant { primary, secondary, ghost, danger }

class TTMButton extends StatefulWidget {
  const TTMButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TtmButtonVariant.primary,
    this.icon,
    this.expanded = true,
    this.busy = false,
    this.pill = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final TtmButtonVariant variant;
  final IconData? icon;

  /// `true`면 부모 너비를 가득 채운다(기본). 모달 인라인 버튼은 `false`로.
  final bool expanded;

  /// 비동기 작업 중 스피너를 보여주고 입력을 막는다. 중복 탭 방지용.
  final bool busy;

  /// 브랜드 기본 — pill radius. 좁은 레이아웃에서만 `false`로.
  final bool pill;

  @override
  State<TTMButton> createState() => _TTMButtonState();
}

class _TTMButtonState extends State<TTMButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceStyle = Theme.of(context).extension<TtmSurfaceStyle>();
    final enabled = widget.onPressed != null && !widget.busy;

    final palette = _palette(isDark);
    final usePrimaryDepth =
        widget.variant == TtmButtonVariant.primary && surfaceStyle != null;

    final labelRow = widget.busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: palette.foreground,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: palette.foreground),
                const SizedBox(width: TtmSpacing.sm),
              ],
              Text(
                widget.label,
                style: TtmTypography.button.copyWith(color: palette.foreground),
              ),
            ],
          );

    final minHeight = 52.0;
    final radius = BorderRadius.circular(
      widget.pill ? TtmRadius.pill : TtmRadius.md,
    );

    Widget core;
    if (widget.variant == TtmButtonVariant.primary && usePrimaryDepth) {
      core = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? widget.onPressed : null,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.18),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Ink(
            height: minHeight,
            decoration: BoxDecoration(
              gradient: surfaceStyle.primaryButtonGradient,
              borderRadius: radius,
              boxShadow: enabled ? surfaceStyle.primaryButtonShadow : null,
            ),
            child: Center(child: labelRow),
          ),
        ),
      );
    } else {
      core = Material(
        color: palette.background,
        borderRadius: radius,
        elevation: _elevationForVariant(widget.variant, enabled, isDark),
        shadowColor: _shadowColorForVariant(widget.variant, isDark),
        surfaceTintColor: Colors.transparent,
        child: InkWell(
          onTap: enabled ? widget.onPressed : null,
          borderRadius: radius,
          splashColor: palette.foreground.withValues(alpha: 0.08),
          highlightColor: palette.foreground.withValues(alpha: 0.04),
          child: Container(
            height: minHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: palette.border == BorderSide.none
                  ? null
                  : Border.fromBorderSide(palette.border),
            ),
            child: labelRow,
          ),
        ),
      );
    }

    final wrapped = Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.98 : 1,
        duration: TtmMotion.instant,
        curve: TtmMotion.easeOut,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: core),
      ),
    );

    return widget.expanded
        ? SizedBox(width: double.infinity, child: wrapped)
        : wrapped;
  }

  double _elevationForVariant(TtmButtonVariant v, bool enabled, bool isDark) {
    if (!enabled) return 0;
    switch (v) {
      case TtmButtonVariant.primary:
        return 0;
      case TtmButtonVariant.secondary:
        return isDark ? 0 : 0.5;
      case TtmButtonVariant.ghost:
        return 0;
      case TtmButtonVariant.danger:
        return isDark ? 0 : 1;
    }
  }

  Color _shadowColorForVariant(TtmButtonVariant v, bool isDark) {
    switch (v) {
      case TtmButtonVariant.danger:
        return TtmColors.accent.withValues(alpha: isDark ? 0.35 : 0.22);
      default:
        return Colors.black.withValues(alpha: isDark ? 0.4 : 0.12);
    }
  }

  _ButtonPalette _palette(bool isDark) {
    switch (widget.variant) {
      case TtmButtonVariant.primary:
        return _ButtonPalette(
          background: isDark ? TtmColors.primaryDark : TtmColors.primary,
          foreground: Colors.white,
        );
      case TtmButtonVariant.secondary:
        return _ButtonPalette(
          background: isDark
              ? TtmColors.darkSurfaceAlt
              : TtmColors.primaryLight,
          foreground: isDark ? TtmColors.primaryDark : TtmColors.primary,
        );
      case TtmButtonVariant.ghost:
        final color = isDark ? TtmColors.primaryDark : TtmColors.primary;
        return _ButtonPalette(
          background: Colors.transparent,
          foreground: color,
          border: BorderSide(color: color, width: 1.5),
        );
      case TtmButtonVariant.danger:
        return const _ButtonPalette(
          background: TtmColors.accent,
          foreground: Colors.white,
        );
    }
  }
}

class _ButtonPalette {
  const _ButtonPalette({
    required this.background,
    required this.foreground,
    this.border = BorderSide.none,
  });

  final Color background;
  final Color foreground;
  final BorderSide border;
}
