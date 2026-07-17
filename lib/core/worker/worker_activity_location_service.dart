import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:geolocator/geolocator.dart';

import '../../features/match/repositories/matching_repository.dart';

/// 활동 ON 동안 백그라운드·화면 꺼짐에도 GPS를 주기적으로 서버에 반영한다.
///
/// Android: geolocator 포그라운드 알림(「활동 중」)으로 위치 스트림 유지.
class WorkerActivityLocationService {
  StreamSubscription<Position>? _sub;
  String? _workerId;
  Future<void> _transition = Future<void>.value();

  bool get isRunning => _sub != null;

  LocationSettings get _settings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '틈틈 활동 중',
          notificationText: '주변 심부름 알림을 위해 위치를 사용해요',
          notificationChannelName: '활동 중',
          notificationIcon: AndroidResource(name: 'ic_stat_ttm'),
          color: Color(0xFF0B7A75),
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  Future<void> startTracking({
    required String workerId,
    required MatchingRepository repo,
  }) => _serial(() => _startTracking(workerId: workerId, repo: repo));

  Future<void> _startTracking({
    required String workerId,
    required MatchingRepository repo,
  }) async {
    if (_workerId == workerId && _sub != null) return;
    await _stop();
    _workerId = workerId;

    _sub = Geolocator.getPositionStream(locationSettings: _settings).listen((
      pos,
    ) async {
      try {
        await repo.upsertMyPresence(
          workerId: workerId,
          status: 'online',
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } catch (_) {}
    }, onError: (_) {});
  }

  Future<void> stop() => _serial(_stop);

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    _workerId = null;
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _transition.then((_) => action());
    _transition = next.catchError((Object _) {});
    return next;
  }
}
