import 'package:jwt_decode/jwt_decode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 비밀번호 재설정 메일(PKCE `type=recovery`)로 받은 액세스 토큰은 `amr`에 `recovery`가 포함된다.
bool sessionIsPasswordRecoveryMode(Session session) {
  try {
    final payload = Jwt.parseJwt(session.accessToken);
    final amr = payload['amr'];
    if (amr is! List) return false;
    for (final entry in amr) {
      if (entry is Map && entry['method'] == 'recovery') {
        return true;
      }
    }
  } catch (_) {
    return false;
  }
  return false;
}
