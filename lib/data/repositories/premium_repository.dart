import 'package:supabase_flutter/supabase_flutter.dart';

/// Google Play 구독 검증 → Supabase Edge → is_premium 반영.
class PremiumRepository {
  PremiumRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> verifyPlayPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final res = await _client.functions.invoke(
      'verify-play-subscription',
      body: {'purchase_token': purchaseToken, 'product_id': productId},
    );

    if (res.status != 200) {
      final data = res.data;
      final reason = data is Map ? data['reason']?.toString() : null;
      final message = data is Map ? data['message']?.toString() : null;
      throw PremiumVerifyException(
        reason ?? 'verify_failed',
        message ?? '구독을 확인하지 못했어요.',
      );
    }

    final data = res.data;
    if (data is! Map) {
      throw PremiumVerifyException('invalid_response', '응답 형식이 올바르지 않아요.');
    }
    return Map<String, dynamic>.from(data);
  }

  /// Play 구독 전 — 설정에서 프리미엄 혜택 테스트용.
  Future<bool> setPremiumTestMode(bool enabled) async {
    final raw = await _client.rpc(
      'set_premium_test_mode',
      params: {'p_enabled': enabled},
    );
    if (raw is Map && raw['ok'] == true) {
      return raw['is_premium'] == true;
    }
    return false;
  }

  Future<bool> refreshMyEntitlement() async {
    final raw = await _client.rpc('refresh_my_premium_entitlement');
    if (raw is Map && raw['ok'] == true) {
      return raw['is_premium'] == true;
    }
    return false;
  }
}

class PremiumVerifyException implements Exception {
  PremiumVerifyException(this.reason, this.message);

  final String reason;
  final String message;

  @override
  String toString() => message;
}
