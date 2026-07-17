import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/push/fcm_push_service.dart';
import '../../core/push/push_route_handler.dart';
import '../providers/auth_providers.dart';
import '../repositories/fcm_token_repository.dart';

final fcmTokenRepositoryProvider = Provider<FcmTokenRepository>((ref) {
  return FcmTokenRepository(ref.watch(supabaseClientProvider));
});

/// 푸시 탭으로 이동할 때 라우터가 소비한다.
final pendingPushNavigationProvider = StateProvider<PushNavigationIntent?>(
  (ref) => null,
);

final fcmPushServiceProvider = Provider<FcmPushService>((ref) {
  return FcmPushService(
    tokenRepository: ref.watch(fcmTokenRepositoryProvider),
    onNavigate: (intent) {
      ref.read(pendingPushNavigationProvider.notifier).state = intent;
    },
  );
});

/// main() 이후 1회 초기화 + 로그인 세션에 따라 토큰 등록.
final fcmBootstrapProvider = FutureProvider<void>((ref) async {
  final service = ref.read(fcmPushServiceProvider);
  await service.initialize();

  ref.listen(authUserIdProvider, (prev, next) {
    service.bindUserSession(next);
  }, fireImmediately: true);
});
