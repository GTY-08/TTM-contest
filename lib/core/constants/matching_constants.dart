/// 매칭 엔진·UI 에서 공통으로 쓰는 상수.
class TtmMatchingConstants {
  const TtmMatchingConstants._();

  /// 단계마다 반경을 넓히기 전 대기 시간(초). Supabase `stage_interval_seconds` 와 맞춘다.
  static const int defaultStageIntervalSeconds = 6;

  static const int matchingStageCount = 10;

  /// 최대 반경(10단계) 도달 후 매칭 실패 전 유지 시간(초). Supabase `advance_request_stage` 와 맞춘다.
  static const int maxStageHoldSeconds = 20;

  /// 도보 ETA: 거리(m) ÷ 이 값 = 이동 분 (4km/h).
  static const double walkMetersPerMinute = 67;
}
