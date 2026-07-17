import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'dashboard_colors.dart';
import 'ttm_semantic_colors.dart';
import 'ttm_surface_style.dart';

/// 앱 전역 [ThemeData] 팩토리.
class TtmTheme {
  const TtmTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _buildDashboardDark();

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final primary = isDark ? TtmColors.primaryDark : TtmColors.primary;
    final background = isDark
        ? TtmColors.darkBackground
        : TtmColors.lightBackground;
    final surface = isDark ? TtmColors.darkSurface : TtmColors.lightSurface;
    final surfaceAlt = isDark
        ? TtmColors.darkSurfaceAlt
        : TtmColors.lightSurfaceAlt;
    final onSurface = isDark
        ? TtmColors.darkOnSurface
        : TtmColors.lightOnSurface;
    final subtle = isDark ? TtmColors.darkSubtle : TtmColors.lightSubtle;
    final divider = isDark ? TtmColors.darkDivider : TtmColors.lightDivider;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF0A2E1A)
          : TtmColors.primaryLight,
      onPrimaryContainer: primary,
      secondary: TtmColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: TtmColors.accentLight,
      onSecondaryContainer: TtmColors.accent,
      tertiary: TtmColors.premiumGold,
      onTertiary: const Color(0xFF1A1A1A),
      error: TtmColors.accent,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: subtle,
      outline: divider,
      outlineVariant: divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark
          ? TtmColors.lightOnSurface
          : TtmColors.darkOnSurface,
      onInverseSurface: isDark ? TtmColors.lightSurface : TtmColors.darkSurface,
      inversePrimary: isDark ? TtmColors.primary : TtmColors.primaryDark,
    );

    final textTheme = TtmTypography.textThemeFor(
      onSurface: onSurface,
      subtle: subtle,
    );

    final inputRadius = BorderRadius.circular(TtmRadius.md);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[
        isDark ? TtmSurfaceStyle.dark(primary) : TtmSurfaceStyle.light(primary),
        isDark ? TtmSemanticColors.dark() : TtmSemanticColors.light(),
      ],
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      fontFamily: TtmFontFamily.suit,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TtmTypography.headline.copyWith(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: subtle),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          TtmTypography.label.copyWith(color: subtle),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: subtle);
        }),
        elevation: 1,
        height: 64,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtmRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtmRadius.lg),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtmRadius.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TtmSpacing.lg,
          vertical: TtmSpacing.md,
        ),
        labelStyle: TtmTypography.label.copyWith(color: subtle),
        hintStyle: TtmTypography.body.copyWith(color: subtle),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: TtmTypography.button,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TtmRadius.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: subtle,
          textStyle: TtmTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          textStyle: TtmTypography.button,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TtmRadius.pill),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: subtle),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: isDark ? 0.35 : 0.28),
        selectionHandleColor: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: TtmTypography.body.copyWith(color: surface),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtmRadius.md),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// 설정에서 「다크」 선택 시 — 수행자 대시보드 팔레트.
  static ThemeData _buildDashboardDark() {
    const primary = TtmDashboardColors.accent;
    const background = TtmDashboardColors.background;
    const surface = TtmDashboardColors.surface;
    const surfaceAlt = TtmDashboardColors.surfaceRaised;
    const onSurface = TtmDashboardColors.textPrimary;
    const subtle = TtmDashboardColors.textSecondary;
    const divider = TtmDashboardColors.border;

    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: TtmDashboardColors.onAccent,
      primaryContainer: Color(0xFF1A2210),
      onPrimaryContainer: primary,
      secondary: TtmDashboardColors.urgent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF2A1512),
      onSecondaryContainer: TtmDashboardColors.urgent,
      tertiary: TtmColors.premiumGold,
      onTertiary: Color(0xFF1A1A1A),
      error: TtmDashboardColors.urgent,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: subtle,
      outline: divider,
      outlineVariant: divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: TtmColors.lightOnSurface,
      onInverseSurface: TtmColors.lightSurface,
      inversePrimary: TtmColors.primary,
    );

    final textTheme = TtmTypography.textThemeFor(
      onSurface: onSurface,
      subtle: subtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[
        TtmSurfaceStyle.dashboard(),
        TtmSemanticColors.dashboard(),
      ],
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      fontFamily: TtmFontFamily.suit,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TtmTypography.headline.copyWith(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: subtle),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: TtmDashboardColors.onAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtmRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }
}
