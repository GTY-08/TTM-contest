import 'package:flutter/material.dart';

/// 폰트 패밀리 이름은 `pubspec.yaml`의 `fonts:` 블록과 1:1로 맞춰야 한다.
class TtmFontFamily {
  const TtmFontFamily._();

  /// 제목·숫자·버튼용. Pretendard.
  static const String pretendard = 'Pretendard';

  /// 본문·라벨용. SUIT.
  static const String suit = 'SUIT';
}

/// `plans/틈틈_디자인_시스템.md` §3 타이포 스케일을 코드로 옮긴 것.
///
/// 실제 화면에서는 가급적 [Theme.of(context).textTheme] 의 의미 슬롯
/// (`titleLarge`, `bodyMedium` 등) 을 통해 가져오고, 토큰 직접 참조는
/// 디자인 사양 그대로 박아야 할 때만 사용한다.
class TtmTypography {
  const TtmTypography._();

  static const TextStyle display = TextStyle(
    fontFamily: TtmFontFamily.pretendard,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: TtmFontFamily.pretendard,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.2,
  );

  static const TextStyle title = TextStyle(
    fontFamily: TtmFontFamily.pretendard,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: TtmFontFamily.suit,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: TtmFontFamily.suit,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontFamily: TtmFontFamily.suit,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 금액·거리·시간 등 숫자에 사용. 표 모양(tabular)으로 정렬되도록 설정.
  static const TextStyle number = TextStyle(
    fontFamily: TtmFontFamily.pretendard,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// L0 — 금액 (홈·카드 핵심).
  static const TextStyle moneyDisplay = TextStyle(
    fontFamily: TtmFontFamily.pretendard,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// L5 — 섹션 eyebrow.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: TtmFontFamily.suit,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.6,
  );

  /// L2 — 거리·시간 metric.
  static const TextStyle metric = TextStyle(
    fontFamily: TtmFontFamily.pretendard,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// 모든 버튼에 동일하게 적용되는 라벨 스타일.
  static const TextStyle button = TextStyle(
    fontFamily: TtmFontFamily.pretendard,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// 위 토큰들을 Material 3 [TextTheme] 슬롯에 매핑한다.
  static TextTheme textThemeFor({
    required Color onSurface,
    required Color subtle,
  }) {
    return TextTheme(
      displayLarge: display.copyWith(color: onSurface, fontSize: 28),
      displayMedium: display.copyWith(color: onSurface),
      displaySmall: display.copyWith(color: onSurface, fontSize: 22),
      headlineLarge: headline.copyWith(color: onSurface, fontSize: 22),
      headlineMedium: headline.copyWith(color: onSurface),
      headlineSmall: headline.copyWith(color: onSurface, fontSize: 18),
      titleLarge: title.copyWith(color: onSurface, fontSize: 18),
      titleMedium: title.copyWith(color: onSurface),
      titleSmall: title.copyWith(color: onSurface, fontSize: 14),
      bodyLarge: body.copyWith(color: onSurface, fontSize: 16),
      bodyMedium: body.copyWith(color: onSurface),
      bodySmall: body.copyWith(color: subtle, fontSize: 12),
      labelLarge: button.copyWith(color: onSurface),
      labelMedium: label.copyWith(color: subtle),
      labelSmall: label.copyWith(color: subtle, fontSize: 11),
    );
  }
}
