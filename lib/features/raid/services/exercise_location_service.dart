import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/exercise_matching_models.dart';

class ExerciseLocationException implements Exception {
  const ExerciseLocationException(this.reason);
  final String reason;
}

class ExerciseLocationService {
  Future<ExerciseLocationSnapshot> current({bool request = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ExerciseLocationException('location_service_disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const ExerciseLocationException('location_permission_denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ExerciseLocationException('location_permission_forever');
    }
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } on TimeoutException {
      throw const ExerciseLocationException('location_timeout');
    } on LocationServiceDisabledException {
      throw const ExerciseLocationException('location_service_disabled');
    } on PermissionDeniedException {
      throw const ExerciseLocationException('location_permission_denied');
    }
    if (position.accuracy > 200) {
      throw const ExerciseLocationException('inaccurate_location');
    }
    return ExerciseLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
    );
  }
}

String exerciseLocationMessage(String reason) => switch (reason) {
  'location_service_disabled' => '휴대폰 위치 서비스를 켜 주세요.',
  'location_permission_denied' => '주변 거리 확인을 위해 위치 권한이 필요해요.',
  'location_permission_forever' => '설정에서 틈틈의 위치 권한을 허용해 주세요.',
  'location_timeout' => '현재 위치 확인이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
  'inaccurate_location' => '현재 위치 정확도가 낮아요. 잠시 후 다시 시도해 주세요.',
  'stale_location' => '위치가 오래되어 다시 확인이 필요해요.',
  'outside_raid_range' => '레이드 장소 5km 안에서만 참가할 수 있어요.',
  'outside_match_range' => '선택한 매칭 거리 안에서만 수락할 수 있어요.',
  'outside_venue_range' => '현재 위치에서 5km 이내 운동 장소를 선택해 주세요.',
  'schedule_conflict' => '이미 확정된 운동 일정과 시간이 겹쳐요.',
  'active_match_exists' => '진행 중인 빠른 운동 매칭이 있어요.',
  'offer_expired' => '이 매칭 제안은 이미 종료되었어요.',
  'raid_full' => '레이드 모집 인원이 모두 찼어요.',
  'insufficient_balance' => '참가비를 보관할 잔액이 부족해요.',
  _ => '처리하지 못했어요. 잠시 후 다시 시도해 주세요.',
};
