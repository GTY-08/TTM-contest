import 'package:flutter/material.dart';

/// 카드·네비·버튼 — 프리미엄 깊이(토스·핀테크 스타일).
@immutable
class TtmSurfaceStyle extends ThemeExtension<TtmSurfaceStyle> {
  const TtmSurfaceStyle({
    required this.primaryButtonGradient,
    required this.primaryButtonShadow,
    required this.cardShadow,
    required this.cardSheenGradient,
    required this.navBarShadow,
    required this.fabShadow,
  });

  final LinearGradient primaryButtonGradient;
  final List<BoxShadow> primaryButtonShadow;
  final List<BoxShadow> cardShadow;
  final LinearGradient cardSheenGradient;
  final List<BoxShadow> navBarShadow;
  final List<BoxShadow> fabShadow;

  static TtmSurfaceStyle of(BuildContext context) {
    final ext = Theme.of(context).extension<TtmSurfaceStyle>();
    assert(ext != null, 'TtmSurfaceStyle가 ThemeData.extensions에 없습니다.');
    return ext!;
  }

  static List<BoxShadow> _premiumCard(bool isDark) => [
    if (!isDark)
      BoxShadow(
        color: const Color(0xFF185944).withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
      blurRadius: isDark ? 12 : 16,
      offset: Offset(0, isDark ? 4 : 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
      blurRadius: isDark ? 32 : 32,
      offset: Offset(0, isDark ? 12 : 12),
    ),
  ];

  static LinearGradient _cardSheen(bool isDark) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0),
          ]
        : [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
  );

  static List<BoxShadow> _navBar(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.11),
      blurRadius: isDark ? 16 : 20,
      offset: const Offset(0, -4),
    ),
  ];

  static List<BoxShadow> _fab(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static TtmSurfaceStyle light(Color primary) {
    final top = Color.lerp(primary, Colors.white, 0.12)!;
    final bottom = Color.lerp(primary, Colors.black, 0.12)!;
    return TtmSurfaceStyle(
      primaryButtonGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ),
      primaryButtonShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.28),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
      cardShadow: _premiumCard(false),
      cardSheenGradient: _cardSheen(false),
      navBarShadow: _navBar(false),
      fabShadow: _fab(false),
    );
  }

  static TtmSurfaceStyle dark(Color primary) {
    final top = Color.lerp(primary, Colors.white, 0.08)!;
    final bottom = Color.lerp(primary, Colors.black, 0.22)!;
    return TtmSurfaceStyle(
      primaryButtonGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ),
      primaryButtonShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
      cardShadow: _premiumCard(true),
      cardSheenGradient: _cardSheen(true),
      navBarShadow: _navBar(true),
      fabShadow: _fab(true),
    );
  }

  static TtmSurfaceStyle dashboard() {
    return TtmSurfaceStyle(
      primaryButtonGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF50C88C), Color(0xFF2E9B6A)],
      ),
      primaryButtonShadow: [
        BoxShadow(
          color: Color(0x2038B27C),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
      cardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
      cardSheenGradient: _cardSheen(true),
      navBarShadow: _navBar(true),
      fabShadow: _fab(true),
    );
  }

  @override
  TtmSurfaceStyle copyWith({
    LinearGradient? primaryButtonGradient,
    List<BoxShadow>? primaryButtonShadow,
    List<BoxShadow>? cardShadow,
    LinearGradient? cardSheenGradient,
    List<BoxShadow>? navBarShadow,
    List<BoxShadow>? fabShadow,
  }) {
    return TtmSurfaceStyle(
      primaryButtonGradient:
          primaryButtonGradient ?? this.primaryButtonGradient,
      primaryButtonShadow: primaryButtonShadow ?? this.primaryButtonShadow,
      cardShadow: cardShadow ?? this.cardShadow,
      cardSheenGradient: cardSheenGradient ?? this.cardSheenGradient,
      navBarShadow: navBarShadow ?? this.navBarShadow,
      fabShadow: fabShadow ?? this.fabShadow,
    );
  }

  @override
  TtmSurfaceStyle lerp(ThemeExtension<TtmSurfaceStyle>? other, double t) {
    if (other is! TtmSurfaceStyle) return this;
    return t < 0.5 ? this : other;
  }
}
