import 'dart:async' show runZonedGuarded, unawaited;
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/push/push_route_handler.dart';
import 'core/router/app_router.dart';
import 'core/storage/prefs.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/auth_providers.dart';
import 'data/providers/home_navigation_provider.dart';
import 'data/providers/push_providers.dart';
import 'data/providers/theme_providers.dart';

bool _crashlyticsReady = false;

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      await Env.load();

      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: true,
        ),
      );

      if (Platform.isAndroid || Platform.isIOS) {
        await Firebase.initializeApp();
        _configureCrashReporting();
        final session = Supabase.instance.client.auth.currentSession;
        await _syncCrashlyticsUser(session?.user.id);
      }

      if (Platform.isAndroid || Platform.isIOS) {
        await FlutterNaverMap().init(clientId: Env.naverMapClientId);
      }

      final sp = await SharedPreferences.getInstance();
      final prefs = Prefs(sp);

      if (Platform.isAndroid || Platform.isIOS) {
        await sp.setString('widget_supabase_url', Env.supabaseUrl);
        await sp.setString('widget_anon_key', Env.supabaseAnonKey);
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          await sp.setString('widget_auth_token', session.accessToken);
        }
      }

      runApp(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const TtmApp(),
        ),
      );
    },
    (error, stackTrace) {
      if (_crashlyticsReady) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: true,
        );
      }
    },
  );
}

class TtmApp extends ConsumerWidget {
  const TtmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.watch(fcmBootstrapProvider);

    ref.listen<PushNavigationIntent?>(pendingPushNavigationProvider, (
      _,
      intent,
    ) {
      if (intent == null) return;
      ref.read(pendingPushNavigationProvider.notifier).state = null;

      if (intent.homeTabIndex != null) {
        ref.read(homeTabIndexProvider.notifier).state = intent.homeTabIndex!;
      }

      final path = intent.resolveGoPath();
      if (path != null && path.isNotEmpty) {
        router.go(path);
      } else if (intent.homeTabIndex != null) {
        router.go(AppRoutes.home);
      }
    });

    ref.listen(authStateChangesProvider, (_, next) {
      final state = next.asData?.value;
      if (state == null) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        router.go(AppRoutes.resetPassword);
      }
      unawaited(_syncCrashlyticsUser(state.session?.user.id));
      if (Platform.isAndroid) {
        unawaited(_syncWidgetAuthToken(state.session?.accessToken));
      }
    });

    return MaterialApp.router(
      title: '틈틈',
      debugShowCheckedModeBanner: false,
      theme: TtmTheme.light,
      darkTheme: TtmTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}

void _configureCrashReporting() {
  _crashlyticsReady = true;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
    return true;
  };
}

Future<void> _syncCrashlyticsUser(String? userId) async {
  if (!_crashlyticsReady) return;
  await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
}

Future<void> _syncWidgetAuthToken(String? token) async {
  final sp = await SharedPreferences.getInstance();
  if (token != null) {
    await sp.setString('widget_auth_token', token);
  } else {
    await sp.remove('widget_auth_token');
  }
}
