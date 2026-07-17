import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';

/// Supabase Auth 호출을 한 곳에 모아두는 얇은 래퍼.
///
/// 화면·컨트롤러는 절대로 `Supabase.instance.client.auth.*` 를 직접 부르지 않고
/// 이 클래스를 통해서만 호출한다. 그래야:
///   - 테스트에서 mock 으로 갈아끼우기 쉽다
///   - 에러 메시지 한국어 변환 등의 횡단 관심사를 한 곳에서 처리할 수 있다
class AuthRepository {
  AuthRepository(this._supabase);

  final SupabaseClient _supabase;

  GoTrueClient get _auth => _supabase.auth;

  Session? get currentSession => _auth.currentSession;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  // ── 이메일/비밀번호 ────────────────────────────────────────

  /// 신규 가입. 이메일 확인이 꺼져 있으면 세션과 함께 즉시 로그인되고,
  /// 켜져 있으면 사용자만 생성되고 세션은 null 일 수 있다.
  /// [nickname] 이 비면 `handle_new_user` 가 임시로 `'틈틈'` 을 넣고, `/signup` 에서 확정한다.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? nickname,
  }) {
    final emailRedirectTo = Env.supabaseEmailConfirmRedirectUrl.trim();
    return _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo.isEmpty ? null : emailRedirectTo,
      data: {if (nickname != null && nickname.isNotEmpty) 'nickname': nickname},
    );
  }

  /// 가입 직후 인증 메일을 못 받았을 때. [OtpType.signup] 재전송.
  Future<void> resendSignupConfirmationEmail(String email) {
    final redirect = Env.supabaseEmailConfirmRedirectUrl.trim();
    return _auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: redirect.isEmpty ? null : redirect,
    );
  }

  /// 가입 인증 메일에 들어 있는 OTP 코드를 검증한다.
  Future<AuthResponse> verifySignupEmailOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.signup,
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    final redirectTo = Env.supabasePasswordResetRedirectUrl.trim();
    if (redirectTo.isEmpty) {
      return _auth.resetPasswordForEmail(email);
    }
    return _auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  /// Supabase 대시보드에 Kakao/Google provider 가 켜져 있고,
  /// Redirect URLs 에 [Env] 의 앱 콜백 URL 이 등록돼 있어야 한다.
  Future<bool> signInWithOAuthProvider(OAuthProvider provider) {
    return _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : Env.supabaseEmailConfirmRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<bool> signInWithKakaoOAuth() =>
      signInWithOAuthProvider(OAuthProvider.kakao);

  Future<bool> signInWithGoogleOAuth() =>
      signInWithOAuthProvider(OAuthProvider.google);

  // ── 공통 ───────────────────────────────────────────────────

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async {
    final response = await _supabase.functions.invoke('delete-account');
    final data = response.data;
    if (data is Map && data['ok'] == true) {
      await _auth.signOut();
      return;
    }
    final reason = data is Map ? data['reason'] : null;
    throw StateError(reason?.toString() ?? 'delete_account_failed');
  }
}
