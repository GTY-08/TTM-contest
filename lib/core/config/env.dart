import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dart:io';

/// `.env.local` 파일에서 환경 변수를 읽어오는 헬퍼.
///
/// 절대 코드에 키를 박지 말고, 모든 외부 서비스 키는 이 클래스를 통해서만 접근한다.
/// 빈 값이거나 누락된 키를 사용하려고 하면 [StateError] 발생 → 초기화 실패를 빠르게 감지.
class Env {
  const Env._();

  /// 네이티브 앱 전용 Supabase Auth 리다이렉트. Site URL·Redirect URLs·Android/iOS 딥링크와 동일해야 한다.
  static const String supabaseAuthCallbackUrlDefault = 'ttm://auth/callback';

  static Map<String, String> _values = const {};

  /// `main()` 진입 직후 가장 먼저 호출. WidgetsFlutterBinding 초기화 후, runApp 전에.
  static Future<void> load() async {
    if (kIsWeb) {
      throw StateError(
        'Web에서는 .env.local 파일 로드를 지원하지 않습니다. '
        '--dart-define 또는 별도 설정 주입 방식을 사용하세요.',
      );
    }

    // Android/iOS: 작업 디렉터리가 의미 없음 → asset 번들(`pubspec.yaml` 등록)에서 로드.
    if (Platform.isAndroid || Platform.isIOS) {
      await dotenv.load(fileName: '.env.local');
      _values = Map<String, String>.from(dotenv.env);
      _require('SUPABASE_URL');
      _require('SUPABASE_ANON_KEY');
      return;
    }

    // Windows/macOS/Linux: 프로젝트 루트의 파일을 직접 읽음(번들에 비밀 포함 안 함).
    final candidates = <File>[
      File('.env.local'),
      File('${File(Platform.resolvedExecutable).parent.path}\\.env.local'),
      File(
        '${File(Platform.resolvedExecutable).parent.parent.path}\\.env.local',
      ),
      File('c:\\errand2\\.env.local'),
    ];

    final file = await _firstExisting(candidates);
    if (file == null) {
      throw StateError(
        '.env.local 파일을 찾을 수 없습니다. '
        '현재 작업 디렉토리: ${Directory.current.path}',
      );
    }

    final content = await file.readAsString();
    _values = _parseDotEnv(content);

    _require('SUPABASE_URL');
    _require('SUPABASE_ANON_KEY');
  }

  static Future<File?> _firstExisting(List<File> files) async {
    for (final f in files) {
      try {
        if (await f.exists()) return f;
      } catch (_) {
        // ignore
      }
    }
    return null;
  }

  // ── Supabase ────────────────────────────────────────────
  static String get supabaseUrl => _require('SUPABASE_URL');

  /// 대시보드의 **Publishable key** (`sb_publishable_...`) 또는 Legacy **anon** JWT (`eyJ...`) 를
  /// `.env.local`의 `SUPABASE_ANON_KEY`에 넣는다. (변수 이름은 레거시 관습 유지.)
  /// **Secret key** / service_role 은 여기 넣지 말 것.
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  /// 비밀번호 재설정 메일 링크에서 앱으로 돌아올 때 사용할 Redirect URL.
  ///
  /// 비우면 [supabaseAuthCallbackUrlDefault] 사용.
  /// Supabase Dashboard → Auth → URL Configuration:
  /// - **Site URL** 도 동일 URL 권장(앱만 있을 때)
  /// - **Redirect URLs** 에 반드시 등록
  static String get supabasePasswordResetRedirectUrl => _trimmedOrDefault(
    'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
    supabaseAuthCallbackUrlDefault,
  );

  /// 이메일 가입(Confirm email) 링크에서 앱으로 돌아올 Redirect URL.
  ///
  /// 비우면 [supabaseAuthCallbackUrlDefault] 사용.
  /// Redirect URLs 화이트리스트에 동일 문자열 등록 필요.
  static String get supabaseEmailConfirmRedirectUrl => _trimmedOrDefault(
    'SUPABASE_EMAIL_CONFIRM_REDIRECT_URL',
    supabaseAuthCallbackUrlDefault,
  );

  // ── Firebase / FCM ──────────────────────────────────────
  /// google-services.json / GoogleService-Info.plist 가 실제 FCM 연결을 담당하므로
  /// 여기는 디버그 확인용 또는 Edge Function 호출 시 참고용.
  static String get firebaseProjectId => _optional('FIREBASE_PROJECT_ID');

  // ── 네이버 클라우드 맵 ──────────────────────────────────
  static String get naverMapClientId => _require('NAVER_MAP_CLIENT_ID');

  /// Geocoding(주소 검색). Maps Client Secret 과 동일 키.
  static String get naverMapClientSecret =>
      _optional('NAVER_MAP_CLIENT_SECRET');

  static String _require(String key) {
    final value = _values[key];
    if (value == null || value.isEmpty) {
      throw StateError('환경 변수 "$key" 가 비어있습니다. .env.local 파일을 확인하세요.');
    }
    return value;
  }

  static String _optional(String key) => _values[key] ?? '';

  static String _trimmedOrDefault(String key, String def) {
    final v = _values[key]?.trim();
    if (v == null || v.isEmpty) return def;
    return v;
  }

  static Map<String, String> _parseDotEnv(String input) {
    final out = <String, String>{};
    for (final rawLine in input.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;

      final idx = line.indexOf('=');
      if (idx <= 0) continue;

      final k = line.substring(0, idx).trim();
      var v = line.substring(idx + 1).trim();

      // 양끝 따옴표(단/쌍) 제거 (기본 케이스만)
      if (v.length >= 2) {
        final first = v[0];
        final last = v[v.length - 1];
        if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
          v = v.substring(1, v.length - 1);
        }
      }

      out[k] = v;
    }
    return out;
  }
}
