import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/auth_providers.dart';
import '../../../data/repositories/premium_repository.dart';

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  return PremiumRepository(ref.watch(supabaseClientProvider));
});
