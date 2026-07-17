import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widget/ttm_widget_sync_service.dart';
import 'auth_providers.dart';

/// 활동 ON/OFF 홈 위젯의 "직접 시간 설정" 딥링크 요청 플래그.
///
/// 라우터가 `/home?activitySheet=1` 진입 시 true 로 올리고,
/// [TtmWorkerPresenceHero] 가 이를 감지해 시간 설정 시트를 연 뒤 다시 내린다.
final activityDurationSheetRequestProvider = StateProvider<bool>((_) => false);

/// Android 홈 화면 "활동 ON/OFF" 위젯을 worker_presence 상태와 자동 동기화한다.
///
/// `TtmApp.build()` 안에서 `ref.watch(activityWidgetSyncProvider)` 로 활성화.
/// 앱에서 활동을 켜고 끄면(또는 위젯 조작이 서버에 반영되면) realtime 스트림을
/// 통해 위젯 프리퍼런스가 갱신되고 위젯이 다시 그려진다.
final activityWidgetSyncProvider = Provider<void>((ref) {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  ref.listen(myWorkerPresenceProvider, (_, next) {
    // 로딩/에러 중의 null 은 "행 없음(오프라인)"이 아니므로 위젯에 쓰면 안 된다.
    // 특히 iOS 는 위젯이 직접 켠 상태를 앱 시작 직후의 로딩 null 이 덮어쓸 수 있다.
    if (next.isLoading || next.hasError) return;
    unawaited(TtmWidgetSyncService.syncActivityState(next.valueOrNull));
  }, fireImmediately: true);
});
