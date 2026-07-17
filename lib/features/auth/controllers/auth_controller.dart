import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/auth_providers.dart';

/// 화면에서 직접 호출하는 인증 액션들의 진입점.
///
/// [AsyncNotifier] 의 상태(`AsyncValue<void>`) 는 다음 의미로 사용한다.
///   - `AsyncData(null)`  : 유휴 상태 (마지막 액션 성공 또는 시작 전)
///   - `AsyncLoading`     : 처리 중 (버튼 비활성화·스피너)
///   - `AsyncError`       : 마지막 액션이 실패. 화면이 SnackBar 등으로 메시지 노출.
///
/// 라우팅(가입 후 어디로 가야 하나)은 라우터의 redirect 가 자동 처리하므로
/// 컨트롤러는 절대 직접 `context.go(...)` 를 호출하지 않는다.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // 유휴 상태로 시작.
  }

  // ── 이메일 ─────────────────────────────────────────────────

  /// 신규 가입: 이메일·비밀번호만 만들고, 닉네임은 `/signup` 에서만 받는다.
  ///
  /// 대시보드에서 **Confirm email** 이 켜져 있으면 보통 [AuthResponse.session] 이 null 이고
  /// 인증 메일 발송을 기대할 수 있다. 꺼져 있으면 곧바로 세션이 온다.
  Future<EmailSignUpOutcome> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final auth = ref.read(authRepositoryProvider);
      final res = await auth.signUpWithEmail(email: email, password: password);
      final emailConfirmationPending = res.session == null;
      final confirmationSentAt = res.user?.confirmationSentAt?.trim();
      if (kDebugMode) {
        debugPrint(
          'Email signup response: '
          'session=${res.session != null}, '
          'user=${res.user?.id}, '
          'confirmationSentAt=$confirmationSentAt, '
          'emailConfirmedAt=${res.user?.emailConfirmedAt}',
        );
      }
      if (emailConfirmationPending &&
          (confirmationSentAt == null || confirmationSentAt.isEmpty)) {
        throw const AuthFailureException(
          '가입 요청은 처리됐지만 인증 메일 발송 상태를 확인하지 못했어요. '
          '이미 가입된 이메일이면 로그인하거나, 새 이메일로 다시 시도해 주세요.',
        );
      }
      return EmailSignUpOutcome(
        emailConfirmationPending: emailConfirmationPending,
        confirmationSentAt: confirmationSentAt,
      );
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _run(() async {
      final auth = ref.read(authRepositoryProvider);
      await auth.signInWithEmail(email: email, password: password);
    });
  }

  Future<void> verifySignupEmailOtp({
    required String email,
    required String token,
  }) async {
    await _run(() async {
      final trimmedEmail = email.trim();
      final normalizedToken = token.trim().replaceAll(RegExp(r'\s+'), '');
      if (trimmedEmail.isEmpty) {
        throw const AuthFailureException('이메일을 입력해 주세요.');
      }
      if (normalizedToken.length != 8) {
        throw const AuthFailureException('인증번호 8자리를 입력해 주세요.');
      }
      await ref
          .read(authRepositoryProvider)
          .verifySignupEmailOtp(email: trimmedEmail, token: normalizedToken);
    });
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _run(() async {
      final s = email.trim();
      if (s.isEmpty) {
        throw const AuthFailureException('이메일을 입력해 주세요.');
      }
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(s);
    });
  }

  // ── 공통 ───────────────────────────────────────────────────

  Future<void> signOut() async {
    await _run(() async {
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────

  /// [body] 를 실행하면서 [state] 를 loading→data/error 로 자동 관리.
  /// 반환값을 그대로 돌려준다.
  Future<T> _run<T>(Future<T> Function() body) async {
    state = const AsyncValue.loading();
    try {
      final result = await body();
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      if (kDebugMode) debugPrint('AuthController error: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

/// 이메일 가입 API 성공 직후 UI 문구 분기용.
class EmailSignUpOutcome {
  const EmailSignUpOutcome({
    required this.emailConfirmationPending,
    required this.confirmationSentAt,
  });

  /// true 이면 인증 메일 수신을 기대하는 흐름(대부분 Confirm email ON).
  final bool emailConfirmationPending;

  /// Supabase Auth가 확인 메일 발송 시각을 내려준 경우에만 값이 있다.
  final String? confirmationSentAt;
}

/// 같은 CI 로 이미 가입한 사용자가 있을 때.
/// 화면은 [existing.primaryProvider] 를 보고 "원래 OOO로 가입하셨네요" 안내한다.
/// 사용자에게 그대로 보여줄 한국어 메시지를 들고 있는 단순 에러.
class AuthFailureException implements Exception {
  const AuthFailureException(this.message);
  final String message;

  @override
  String toString() => message;
}
