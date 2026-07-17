import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 의 얇은 도메인 래퍼.
///
/// 사이클 3-1에서는 온보딩 시청 여부 한 가지만 필요. 추후 알림 옵션 캐시,
/// 마지막 본 화면 등 sticky UI 상태도 여기 통해서 들어간다.
class Prefs {
  Prefs(this._sp);

  final SharedPreferences _sp;

  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kThemeMode = 'theme_mode';
  static const _kWaitingMatchRequestId = 'waiting_match_request_id';
  static const _kDeveloperModeEnabled = 'developer_mode_enabled';

  bool get onboardingSeen => _sp.getBool(_kOnboardingSeen) ?? false;

  Future<void> setOnboardingSeen(bool value) =>
      _sp.setBool(_kOnboardingSeen, value);

  ThemeMode get themeMode {
    final raw = _sp.getString(_kThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _sp.setString(_kThemeMode, value);
  }

  /// 매칭 대기 화면 진입 중인 요청 id (앱 강제 종료 시 취소용).
  String? get waitingMatchRequestId => _sp.getString(_kWaitingMatchRequestId);

  Future<void> setWaitingMatchRequestId(String? requestId) async {
    if (requestId == null || requestId.isEmpty) {
      await _sp.remove(_kWaitingMatchRequestId);
      return;
    }
    await _sp.setString(_kWaitingMatchRequestId, requestId);
  }

  Future<void> clearWaitingMatchRequestId() =>
      _sp.remove(_kWaitingMatchRequestId);

  bool get developerModeEnabled => _sp.getBool(_kDeveloperModeEnabled) ?? false;

  Future<void> setDeveloperModeEnabled(bool value) =>
      _sp.setBool(_kDeveloperModeEnabled, value);
}
