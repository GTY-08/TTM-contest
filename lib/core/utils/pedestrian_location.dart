import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// 도보 심부름용 GPS — 최고 정밀도·짧은 갱신 주기.
abstract final class TtmPedestrianLocation {
  /// 수평 오차(m)가 이 값 이하일 때만 서버 반영 (실내·도심에서도 동작하도록 여유).
  static const maxPublishAccuracyM = 80.0;

  /// 로컬 지도 미리보기.
  static const maxPreviewAccuracyM = 100.0;

  static LocationSettings streamSettings({
    ForegroundNotificationConfig? androidForeground,
  }) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: androidForeground,
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  static Future<Position?> obtainPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 18),
      );
    } catch (_) {
      return null;
    }
  }

  static bool isReliableForPublish(Position pos) {
    final acc = pos.accuracy;
    if (acc <= 0) return true;
    return acc <= maxPublishAccuracyM;
  }

  static bool isReliableForPreview(Position pos) {
    final acc = pos.accuracy;
    if (acc <= 0) return true;
    return acc <= maxPreviewAccuracyM;
  }
}
