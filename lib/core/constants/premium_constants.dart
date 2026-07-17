/// Google Play 프리미엄 구독 — Play Console 상품 ID와 동일해야 함.
abstract final class TtmPremiumConstants {
  /// Play Console → 수익 창출 → 구독 → 기본 요금제 ID
  static const String playProductId = 'ttm_premium_monthly';

  /// UI 표시용 (실제 청구 금액은 스토어 ProductDetails 기준)
  static const int listPriceKrw = 19900;

  static String get listPriceLabel =>
      '월 ${listPriceKrw.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
}
