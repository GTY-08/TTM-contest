import 'package:supabase_flutter/supabase_flutter.dart';

class FcmTokenRepository {
  FcmTokenRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<void> upsertToken({
    required String token,
    required String platform,
    String? deviceLabel,
    String? appVersion,
  }) async {
    await _supabase.rpc(
      'upsert_my_fcm_token',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_device_label': deviceLabel,
        'p_app_version': appVersion,
      },
    );
  }

  Future<void> deleteToken(String token) async {
    await _supabase.rpc('delete_my_fcm_token', params: {'p_token': token});
  }
}
