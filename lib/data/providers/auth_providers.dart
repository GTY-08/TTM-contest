import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage/prefs.dart';
import '../models/app_user.dart';
import '../models/received_review.dart';
import '../models/user_restriction.dart';
import '../repositories/auth_repository.dart';
import '../repositories/demo_wallet_repository.dart';
import '../repositories/profile_avatar_repository.dart';
import '../repositories/user_repository.dart';

/// 앱 전역 [SupabaseClient]. main.dart 의 `Supabase.initialize` 이후에만 안전하게 사용 가능.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// [Prefs] 는 비동기 초기화가 필요해서 main.dart 에서 override 한다.
/// 기본값은 절대 사용되면 안 되므로 던진다.
final prefsProvider = Provider<Prefs>((ref) {
  throw UnimplementedError('prefsProvider 는 main.dart 에서 override 해야 합니다.');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseClientProvider));
});

final demoWalletRepositoryProvider = Provider<DemoWalletRepository>((ref) {
  return DemoWalletRepository(ref.watch(supabaseClientProvider));
});

final myDemoWalletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return const <String, dynamic>{'ok': false};
  return ref.read(demoWalletRepositoryProvider).fetchMyWallet();
});

final profileAvatarRepositoryProvider = Provider<ProfileAvatarRepository>((
  ref,
) {
  return ProfileAvatarRepository(ref.watch(supabaseClientProvider));
});

/// Supabase 인증 상태 스트림. 가입/로그인/로그아웃/토큰 갱신을 모두 흘려보낸다.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// 로그인한 사용자의 `auth.users.id`.
///
/// [authStateChangesProvider] 전체를 watch 하면 `TOKEN_REFRESHED` 마다
/// 의존성이 흔들려 [myProfileProvider] 가 무한 재요청될 수 있다.
/// `select` 로 **user id 문자열이 바뀔 때만** 알림이 나가게 고정한다.
final authUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ref.watch(
    authStateChangesProvider.select(
      (async) => async.when(
        data: (state) => state.session?.user.id,
        loading: () => client.auth.currentUser?.id,
        error: (err, stack) => client.auth.currentUser?.id,
      ),
    ),
  );
});

/// 현재 세션. [authUserIdProvider] 가 바뀔 때만 다시 읽는다(토큰 갱신만으로는 재빌드 안 함).
final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authUserIdProvider);
  return ref.read(supabaseClientProvider).auth.currentSession;
});

/// 현재 로그인한 사용자의 `public.users` 프로필.
/// 세션이 없으면 null. 세션이 있는데 프로필이 아직 안 만들어졌을 짧은 구간엔 fetching.
final myProfileProvider = FutureProvider<AppUser?>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return null;
  return ref.read(userRepositoryProvider).fetchMyProfile();
});

final myAdminRoleProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return false;
  return ref.read(userRepositoryProvider).fetchMyAdminRole();
});

final myActiveRestrictionsProvider = StreamProvider<List<UserRestriction>>((
  ref,
) {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) {
    return Stream.value(const []);
  }

  final client = ref.read(supabaseClientProvider);
  final repository = ref.read(userRepositoryProvider);
  final controller = StreamController<List<UserRestriction>>();
  var latestRows = const <Map<String, dynamic>>[];
  var hasRealtimeData = false;

  List<UserRestriction> activeFromRows(List<Map<String, dynamic>> rows) {
    final now = DateTime.now().toUtc();
    final restrictions = rows
        .where((row) {
          if (row['is_active'] != true) return false;
          final startsAt = DateTime.tryParse(
            row['starts_at']?.toString() ?? '',
          );
          final endsAt = DateTime.tryParse(row['ends_at']?.toString() ?? '');
          if (startsAt != null && startsAt.toUtc().isAfter(now)) return false;
          return endsAt == null || endsAt.toUtc().isAfter(now);
        })
        .map(UserRestriction.fromMap)
        .toList(growable: false);
    restrictions.sort((a, b) {
      final severity = a.severityRank.compareTo(b.severityRank);
      if (severity != 0) return severity;
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    });
    return restrictions;
  }

  void emitRealtimeRows() {
    if (controller.isClosed || !hasRealtimeData) return;
    controller.add(activeFromRows(latestRows));
  }

  Future<void> refreshFromRpc() async {
    try {
      final restrictions = await repository.fetchMyActiveRestrictions();
      if (!controller.isClosed && !hasRealtimeData) {
        controller.add(restrictions);
      }
    } catch (error, stackTrace) {
      if (!controller.isClosed && !hasRealtimeData) {
        controller.addError(error, stackTrace);
      }
    }
  }

  unawaited(refreshFromRpc());
  final subscription = client
      .from('user_restrictions')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .listen(
        (rows) {
          hasRealtimeData = true;
          latestRows = rows
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
          emitRealtimeRows();
        },
        onError: (_, _) {
          hasRealtimeData = false;
          unawaited(refreshFromRpc());
        },
      );

  final expiryTimer = Timer.periodic(
    const Duration(seconds: 15),
    (_) => emitRealtimeRows(),
  );

  ref.onDispose(() {
    expiryTimer.cancel();
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
});

final myReceivedReviewsProvider = FutureProvider<List<ReceivedReview>>((
  ref,
) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return const [];
  return ref.read(userRepositoryProvider).fetchMyReceivedReviews();
});

/// 온보딩 슬라이드를 본 적이 있는가. SharedPreferences 영구 저장.
class OnboardingSeenNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(prefsProvider).onboardingSeen;
  }

  Future<void> markSeen() async {
    await ref.read(prefsProvider).setOnboardingSeen(true);
    state = true;
  }

  /// 개발·검증용: 온보딩을 다시 보려면 플래그를 내리고 라우터가 재평가되게 한다.
  Future<void> resetOnboardingForPreview() async {
    await ref.read(prefsProvider).setOnboardingSeen(false);
    state = false;
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeenNotifier, bool>(
  OnboardingSeenNotifier.new,
);

class DeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(prefsProvider).developerModeEnabled;
  }

  Future<void> setEnabled(bool value) async {
    await ref.read(prefsProvider).setDeveloperModeEnabled(value);
    state = value;
  }
}

final developerModeProvider = NotifierProvider<DeveloperModeNotifier, bool>(
  DeveloperModeNotifier.new,
);

/// 라우터 redirect 가 듣는 통합 [Listenable].
///
/// `go_router` 의 `refreshListenable` 은 [Listenable] 을 요구한다.
/// 인증·프로필·온보딩 상태 중 어느 하나라도 바뀌면 값을 한 칸 올려
/// 라우터에 "다시 redirect 평가하라" 고 알린다.
final authRouterRefreshProvider = Provider<Listenable>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen(authUserIdProvider, (_, _) => notifier.value++);
  ref.listen(myProfileProvider, (_, _) => notifier.value++);
  ref.listen(onboardingSeenProvider, (_, _) => notifier.value++);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// 작업자 본인의 `worker_presence` 행. REST 초기값과 Realtime 변경을 함께 반영한다.
final myWorkerPresenceProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .read(supabaseClientProvider)
      .from('worker_presence')
      .stream(primaryKey: ['worker_id'])
      .eq('worker_id', uid)
      .map(
        (rows) => rows.isEmpty ? null : Map<String, dynamic>.from(rows.first),
      );
});
