import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/supabase_auth_session.dart';
import 'ttm_page_transitions.dart';
import '../../data/providers/auth_providers.dart';
import '../../features/auth/screens/email_login_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/email_sign_up_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/chat/screens/active_match_screen.dart';
import '../../features/chat/screens/general_application_chat_screen.dart';
import '../../features/chat/screens/match_chat_screen.dart';
import '../../features/match/screens/general_request_detail_screen.dart';
import '../../features/match/screens/match_waiting_screen.dart';
import '../../features/match/screens/request_create_screen.dart';
import '../../features/premium/screens/premium_screen.dart';
import '../../features/raid/screens/raid_chat_screen.dart';
import '../../features/raid/screens/raid_application_chat_screen.dart';
import '../../features/raid/screens/raid_detail_screen.dart';
import '../../features/raid/screens/exercise_preferences_screen.dart';
import '../../features/raid/screens/exercise_quick_chat_screen.dart';
import '../../features/raid/screens/exercise_quick_match_screen.dart';
import '../dev/dev_boot_screen.dart';

/// 앱 전역 라우트 경로 상수.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String emailLogin = '/login/email';
  static const String emailSignUp = '/signup/email';
  static const String signup = '/signup';
  static const String home = '/home';

  /// 요청 생성·매칭 대기 화면 진입 경로의 공통 prefix.
  static const String requestRoot = '/request';
  static const String requestCreate = '$requestRoot/new';
  static const String raidRoot = '/raid';
  static const String quickMatch = '/quick-match';
  static const String exercisePreferences = '/profile/exercise';

  static const String resetPassword = '/reset-password';

  /// 초기 연동 확인용 임시 화면. 정식 릴리스 직전에 제거 예정.
  static const String dev = '/dev';
  static const String premium = '/premium';
}

/// 앱 전역 라우터.
///
/// redirect 가 인증 상태와 프로필 완성도를 보고 자동 분기한다.
/// 화면이나 컨트롤러는 절대로 직접 `context.go(...)` 로 분기 결정을 하지 않는다 —
/// 그 결정은 오로지 여기서만.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(authRouterRefreshProvider);
  // 위젯 딥링크 cold-start: 앱 미실행 상태에서 위젯 탭 시 인증 완료 후 이동할 경로 임시 저장
  String? pendingWidgetRoute;

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      // 홈 위젯 딥링크: ttm://app/<path>[?query]
      final uri = state.uri;
      if (uri.scheme == 'ttm' && uri.host == 'app' && uri.path.isNotEmpty) {
        final q = uri.query;
        final path = q.isEmpty ? uri.path : '${uri.path}?$q';

        // 이미 인증된 상태면 바로 이동
        final uid = ref.read(authUserIdProvider);
        final profileAsync = ref.read(myProfileProvider);
        if (uid != null &&
            !profileAsync.isLoading &&
            !profileAsync.hasError &&
            (profileAsync.asData?.value?.isProfileComplete ?? false)) {
          return path;
        }
        // 인증 대기 중: 목적지 저장 후 splash로 이동
        pendingWidgetRoute = path;
        return AppRoutes.splash;
      }

      final loc = state.matchedLocation;
      final recoverySession = ref
          .read(supabaseClientProvider)
          .auth
          .currentSession;
      if (recoverySession != null &&
          sessionIsPasswordRecoveryMode(recoverySession)) {
        if (loc != AppRoutes.resetPassword) {
          return AppRoutes.resetPassword;
        }
        return null;
      }

      final onboardingSeen = ref.read(onboardingSeenProvider);

      if (loc == AppRoutes.onboarding) {
        if (onboardingSeen) {
          final uidEarly = ref.read(authUserIdProvider);
          return uidEarly == null ? AppRoutes.login : AppRoutes.splash;
        }
        return null;
      }

      if (!onboardingSeen &&
          loc != AppRoutes.dev &&
          loc != AppRoutes.resetPassword) {
        return AppRoutes.onboarding;
      }

      final uid = ref.read(authUserIdProvider);
      final profileAsync = ref.read(myProfileProvider);

      // 1) 로그인 안 됨 → /login (또는 /login/email)
      if (uid == null) {
        final atLoginArea =
            loc == AppRoutes.login ||
            loc == AppRoutes.emailLogin ||
            loc == AppRoutes.emailSignUp ||
            loc == AppRoutes.resetPassword ||
            loc == AppRoutes.onboarding;
        return atLoginArea ? null : AppRoutes.login;
      }

      // 2) 프로필 로딩 중 → 스플래시에서 대기. (이미 /signup 이면 깜빡임 줄이려 그대로 둠)
      if (profileAsync.isLoading) {
        if (loc == AppRoutes.splash ||
            loc == AppRoutes.signup ||
            loc == AppRoutes.onboarding) {
          return null;
        }
        return AppRoutes.splash;
      }

      // 3) 프로필 조회 실패 → 스플래시 무한 대기 방지: 로그인으로 되돌림
      if (profileAsync.hasError) {
        return AppRoutes.login;
      }

      final profile = profileAsync.asData?.value;
      // 4) 세션은 있는데 public.users 행이 없음(트리거 실패 등) — 로그인으로
      if (profile == null) {
        return AppRoutes.login;
      }

      // 5) 프로필 미완 → /signup
      if (!profile.isProfileComplete) {
        return loc == AppRoutes.signup ? null : AppRoutes.signup;
      }

      // 6) 온보딩을 끝낸 사용자: 인증 화면이면 Home으로 이동.
      const authArea = {
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.emailLogin,
        AppRoutes.signup,
      };
      if (authArea.contains(loc)) {
        final profileDone = profile.isProfileComplete;
        if (profileDone) {
          // 위젯 딥링크 cold-start: 저장된 목적지가 있으면 그쪽으로 이동
          if (pendingWidgetRoute != null) {
            final route = pendingWidgetRoute!;
            pendingWidgetRoute = null;
            return route;
          }
          return AppRoutes.home;
        }
        return null;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) =>
            ttmFadeSlidePage(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => ttmFadeSlidePage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) =>
            ttmFadeSlidePage(key: state.pageKey, child: const LoginScreen()),
        routes: [
          GoRoute(
            path: 'email',
            name: 'emailLogin',
            pageBuilder: (context, state) {
              return ttmFadeSlidePage(
                key: state.pageKey,
                child: const EmailLoginScreen(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        pageBuilder: (context, state) =>
            ttmFadeSlidePage(key: state.pageKey, child: const SignUpScreen()),
      ),
      GoRoute(
        path: AppRoutes.emailSignUp,
        name: 'emailSignUp',
        pageBuilder: (context, state) => ttmFadeSlidePage(
          key: state.pageKey,
          child: const EmailSignUpScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final initialIndex = switch (tab) {
            'create' || 'request' => 1,
            'nearby' || 'find' => 2,
            'activity' => 3,
            'reward' || 'wallet' => 4,
            'profile' => 5,
            _ => 0,
          };
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: HomeScreen(initialIndex: initialIndex),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.raidRoot}/:id',
        name: 'raidDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: RaidDetailScreen(raidId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.raidRoot}/:id/chat',
        name: 'raidChat',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: RaidChatScreen(raidId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.raidRoot}/:id/applications/:participantId/chat',
        name: 'raidApplicationChat',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final participantId = state.pathParameters['participantId'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: RaidApplicationChatScreen(
              raidId: id,
              participantId: participantId,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.quickMatch,
        name: 'exerciseQuickMatch',
        pageBuilder: (context, state) => ttmFadeSlidePage(
          key: state.pageKey,
          child: const ExerciseQuickMatchScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.quickMatch}/:id',
        name: 'exerciseQuickMatchDetail',
        pageBuilder: (context, state) => ttmFadeSlidePage(
          key: state.pageKey,
          child: const ExerciseQuickMatchScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.quickMatch}/:id/chat',
        name: 'exerciseQuickMatchChat',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: ExerciseQuickChatScreen(quickMatchId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.exercisePreferences,
        name: 'exercisePreferences',
        pageBuilder: (context, state) => ttmFadeSlidePage(
          key: state.pageKey,
          child: const ExercisePreferencesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.requestCreate,
        name: 'requestCreate',
        pageBuilder: (context, state) {
          final taskType = state.uri.queryParameters['taskType'];
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: RequestCreateScreen(initialTaskType: taskType),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.requestRoot}/:id/waiting',
        name: 'requestWaiting',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: MatchWaitingScreen(requestId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.requestRoot}/:id/general',
        name: 'generalRequestDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: GeneralRequestDetailScreen(requestId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.requestRoot}/:id/edit',
        name: 'requestEdit',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: RequestCreateScreen(editRequestId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.requestRoot}/:id/active',
        name: 'requestActive',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: ActiveMatchScreen(requestId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.requestRoot}/:id/chat',
        name: 'requestChat',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: MatchChatScreen(requestId: id),
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.requestRoot}/:id/applications/:applicationId/chat',
        name: 'generalApplicationChat',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final applicationId = state.pathParameters['applicationId'] ?? '';
          return ttmFadeSlidePage(
            key: state.pageKey,
            child: GeneralApplicationChatScreen(
              requestId: id,
              applicationId: applicationId,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        pageBuilder: (context, state) => ttmFadeSlidePage(
          key: state.pageKey,
          child: const ResetPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.premium,
        name: 'premium',
        pageBuilder: (context, state) =>
            ttmFadeSlidePage(key: state.pageKey, child: const PremiumScreen()),
      ),
      GoRoute(
        path: AppRoutes.dev,
        name: 'dev',
        pageBuilder: (context, state) =>
            ttmFadeSlidePage(key: state.pageKey, child: const DevBootScreen()),
      ),
    ],
  );
});
