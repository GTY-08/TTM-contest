/// 코너 반경 토큰.
///
/// 디자인 시스템 §5의 컴포넌트 별 반경을 한 곳에 모은 것.
/// 예) 버튼 12~14dp, 카드/모달 14~16dp, 칩 pill, 바텀 네비 32dp.
class TtmRadius {
  const TtmRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;

  /// 카드·시트 (브랜드 가이드 20dp).
  static const double card = 20;

  /// 칩·플로팅 네비처럼 완전히 둥글게 처리할 때.
  static const double pill = 999;
}
