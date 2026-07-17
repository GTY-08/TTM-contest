import 'package:supabase_flutter/supabase_flutter.dart';

class DemoWalletRepository {
  DemoWalletRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> fetchMyWallet() async {
    final raw = await _supabase.rpc('get_my_demo_wallet');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }

  Future<Map<String, dynamic>> chargeMyWallet({int amount = 100000}) async {
    final raw = await _supabase.rpc(
      'charge_my_demo_wallet',
      params: {'p_amount': amount},
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{'ok': false, 'reason': 'unexpected_response'};
  }
}
