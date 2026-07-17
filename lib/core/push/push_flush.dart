import 'package:supabase_flutter/supabase_flutter.dart';

/// push_outbox 적재 직후 match-tick Edge로 FCM 발송을 트리거한다.
Future<void> flushPushOutbox(SupabaseClient supabase) async {
  try {
    await supabase.functions.invoke(
      'match-tick',
      body: const {'flush_only': true},
    );
  } catch (_) {
    // Edge 미배포·네트워크 — DB 이벤트는 이미 커밋됐을 수 있음
  }
}
