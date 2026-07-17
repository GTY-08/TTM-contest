import 'dart:async';
import 'dart:ui';

import 'package:geolocator/geolocator.dart';

import '../utils/pedestrian_location.dart';
import '../../features/match/repositories/matching_repository.dart';

/// 매칭된 심부름 진행 중 작업자 GPS → requests.worker_live_geo.
class MatchedWorkerLocationService {
  StreamSubscription<Position>? _sub;
  String? _requestId;
  Future<void> _transition = Future<void>.value();

  bool get isRunning => _sub != null;

  LocationSettings get _settings => TtmPedestrianLocation.streamSettings(
    androidForeground: const ForegroundNotificationConfig(
      notificationTitle: '틈틈 진행 중',
      notificationText: '요청자에게 위치를 공유하고 있어요',
      notificationChannelName: '매칭 진행',
      notificationIcon: AndroidResource(name: 'ic_stat_ttm'),
      color: Color(0xFF0B7A75),
      setOngoing: true,
    ),
  );

  Future<void> start({
    required String requestId,
    required MatchingRepository repo,
  }) => _serial(() => _start(requestId: requestId, repo: repo));

  Future<void> _start({
    required String requestId,
    required MatchingRepository repo,
  }) async {
    if (_requestId == requestId && _sub != null) return;
    await _stop();
    _requestId = requestId;

    Future<void> publish(Position pos, {required bool strict}) async {
      if (strict && !TtmPedestrianLocation.isReliableForPublish(pos)) return;
      try {
        await repo.publishWorkerMatchLocation(
          requestId: requestId,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } catch (_) {}
    }

    final initial = await TtmPedestrianLocation.obtainPosition();
    if (initial != null) {
      await publish(initial, strict: false);
    }

    var publishedStrict = false;
    _sub = Geolocator.getPositionStream(locationSettings: _settings).listen((
      pos,
    ) async {
      if (!publishedStrict && TtmPedestrianLocation.isReliableForPublish(pos)) {
        publishedStrict = true;
      }
      await publish(pos, strict: publishedStrict);
    }, onError: (_) {});
  }

  Future<void> stop() => _serial(_stop);

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    _requestId = null;
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _transition.then((_) => action());
    _transition = next.catchError((Object _) {});
    return next;
  }
}
