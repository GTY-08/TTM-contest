import 'package:gotrue/gotrue.dart';
import 'package:postgrest/postgrest.dart';

import 'controllers/auth_controller.dart';

/// GoTrue / PostgREST 예외를 사용자에게 보여줄 문장으로 바꾼다.
///
/// [AuthFailureException]은 그대로 두고,
/// 그 외는 코드별 한국어 안내를 우선한다.
String describeAuthError(Object e) {
  if (e is AuthFailureException) return e.message;
  if (e is AuthApiException) {
    return _authApiMessage(e);
  }
  if (e is AuthException) {
    final m = _duplicateRegistrationMessage(e);
    if (m != null) return m;
  }
  if (e is PostgrestException) {
    return _postgrestMessage(e);
  }
  return '문제가 생겼어요. 잠시 후 다시 시도해 주세요. (${e.runtimeType})';
}

String _authApiMessage(AuthApiException e) {
  final dup = _duplicateRegistrationMessage(e);
  if (dup != null) return dup;

  switch (e.code) {
    case 'over_email_send_rate_limit':
      return '같은 이메일로 인증 메일을 너무 자주 보냈어요. 잠시 뒤 다시 시도해 주세요. '
          '계속 오지 않으면 메일 발송 한도나 SMTP 설정을 확인해야 해요.';
    case 'email_address_not_authorized':
      return '이 주소로는 메일을 보낼 수 없게 설정돼 있어요. Supabase 기본 메일러는 '
          '프로젝트 팀 메일 위주로 제한될 수 있어 SMTP 설정을 확인해야 해요.';
    case 'unexpected_failure':
      return '메일 서버에서 오류가 났어요. Supabase 대시보드의 Custom SMTP·'
          '기본 메일 공급자 한도와 Auth 로그를 확인해 주세요. (unexpected_failure)';
    case 'invalid_credentials':
      return '이메일 또는 비밀번호가 맞지 않아요.';
    case 'email_not_confirmed':
      return '이메일 인증이 아직 끝나지 않았어요. 메일의 인증번호를 입력해 주세요.';
    case 'signup_disabled':
      return '지금은 새 가입이 비활성화돼 있어요. 관리자에게 문의해 주세요.';
    case 'otp_expired':
      return '인증번호가 만료됐거나 맞지 않아요. 인증번호를 다시 받아 주세요.';
    case 'over_request_rate_limit':
      return '요청이 너무 잦아요. 잠시 후 다시 시도해 주세요.';
    case 'sms_send_failed':
      return '문자를 보내지 못했어요. Supabase Phone·SMS 설정과 번호 형식을 확인해 주세요.';
    default:
      final msg = e.message.trim();
      final code = e.code?.trim();
      if (msg.isNotEmpty) {
        if (code != null && code.isNotEmpty) return '$msg (코드: $code)';
        return msg;
      }
      return '요청에 실패했어요. (코드: ${code ?? '—'} · HTTP ${e.statusCode})';
  }
}

/// GoTrue 버전·설정에 따라 중복 가입 코드·문구가 달라져서 한곳에서 묶는다.
String? _duplicateRegistrationMessage(AuthException e) {
  final code = e.code?.trim().toLowerCase();
  if (code == 'user_already_registered' ||
      code == 'email_exists' ||
      code == 'user_already_exists') {
    return '이미 가입된 이메일이에요. 로그인 화면에서 시도해 주세요.';
  }
  final m = e.message.toLowerCase();
  if (m.contains('already registered') ||
      m.contains('already been registered') ||
      m.contains('user already exists') ||
      m.contains('email already') ||
      m.contains('email address is already')) {
    return '이미 가입된 이메일이에요. 로그인 화면에서 시도해 주세요.';
  }
  return null;
}

String _postgrestMessage(PostgrestException e) {
  if (e.code == '23505') {
    return '이미 사용 중인 값이에요. (중복)';
  }
  if (e.code == 'PGRST116') {
    return '요청한 데이터를 찾을 수 없어요.';
  }
  final msg = e.message.trim();
  if (msg.isNotEmpty) return msg;
  return '서버와 통신 중 오류가 났어요. (${e.code})';
}
