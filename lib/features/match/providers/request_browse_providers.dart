import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/providers/auth_providers.dart';
import '../models/request_task_type.dart';
import '../models/worker_notification.dart';
import 'match_providers.dart';

/// 요청 탭 필터 상태.
@immutable
class RequestBrowseFilters {
  const RequestBrowseFilters({
    this.matchingMode = 'quick',
    this.maxDistanceM = 2000,
    this.taskTypes = const {},
    this.customTags = const {},
    this.minReward,
    this.maxReward,
    this.minTaskMinutes,
    this.maxTaskMinutes,
  });

  final String matchingMode;

  /// 작업자 기준 탐색 반경(m).
  final int maxDistanceM;

  /// 비어 있으면 작업 유형 제한 없음.
  final Set<String> taskTypes;

  /// 사용자가 직접 입력한 태그 검색어.
  final Set<String> customTags;

  final int? minReward;
  final int? maxReward;
  final int? minTaskMinutes;
  final int? maxTaskMinutes;

  RequestBrowseFilters copyWith({
    String? matchingMode,
    int? maxDistanceM,
    Set<String>? taskTypes,
    Set<String>? customTags,
    int? minReward,
    Object? maxReward = _unset,
    int? minTaskMinutes,
    Object? maxTaskMinutes = _unset,
    bool clearMinReward = false,
    bool clearMaxReward = false,
    bool clearMinTaskMinutes = false,
    bool clearMaxTaskMinutes = false,
  }) {
    return RequestBrowseFilters(
      matchingMode: matchingMode ?? this.matchingMode,
      maxDistanceM: maxDistanceM ?? this.maxDistanceM,
      taskTypes: taskTypes ?? this.taskTypes,
      customTags: customTags ?? this.customTags,
      minReward: clearMinReward ? null : (minReward ?? this.minReward),
      maxReward: clearMaxReward
          ? null
          : (maxReward == _unset ? this.maxReward : maxReward as int?),
      minTaskMinutes: clearMinTaskMinutes
          ? null
          : (minTaskMinutes ?? this.minTaskMinutes),
      maxTaskMinutes: clearMaxTaskMinutes
          ? null
          : (maxTaskMinutes == _unset
                ? this.maxTaskMinutes
                : maxTaskMinutes as int?),
    );
  }

  static const _unset = Object();
}

final requestBrowseFiltersProvider = StateProvider<RequestBrowseFilters>(
  (ref) => const RequestBrowseFilters(),
);

/// GPS 좌표 + 필터로 탐색. [requestBrowseRefreshTickProvider] 를 올리면 재조회.
final requestBrowseResultsProvider =
    FutureProvider.autoDispose<List<WorkerNotification>>((ref) async {
      ref.watch(requestBrowseRefreshTickProvider);
      final filters = ref.watch(requestBrowseFiltersProvider);
      final uid = ref.watch(authUserIdProvider);
      if (uid == null) return const [];

      final coords = ref.watch(requestBrowseCoordsProvider);
      if (filters.matchingMode == 'quick' && coords == null) {
        throw const RequestBrowseLocationRequired();
      }
      final tags = <String>{
        ...RequestTaskType.browseTagsForIds(filters.taskTypes),
        ...filters.customTags,
      }.toList(growable: false);

      final results = await ref
          .read(matchingRepositoryProvider)
          .browseOpenRequests(
            workerId: uid,
            latitude: coords?.latitude ?? 0,
            longitude: coords?.longitude ?? 0,
            maxDistanceM: filters.maxDistanceM,
            tags: tags.isEmpty ? null : tags,
            minReward: filters.minReward,
            maxReward: filters.maxReward,
            minTaskMinutes: filters.minTaskMinutes,
            maxTaskMinutes: filters.maxTaskMinutes,
            matchingMode: filters.matchingMode,
          );

      unawaited(
        _saveNearbyForWidget(
          results,
          coords?.latitude ?? 0,
          coords?.longitude ?? 0,
        ),
      );
      return results;
    });

Future<void> _saveNearbyForWidget(
  List<WorkerNotification> results,
  double lat,
  double lng,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_location', '$lat,$lng');
    final items = results.take(5).map((n) {
      final req = n.request;
      final distKm = n.distanceKm;
      final dist = distKm == null
          ? ''
          : distKm < 1.0
          ? '${(distKm * 1000).round()}m'
          : '${distKm.toStringAsFixed(1)}km';
      return {
        'taskType': req?.taskType ?? 'other',
        'title': req?.title ?? req?.description ?? '',
        'distance': dist,
        'rewardWon': (req?.reward ?? 0).toInt(),
      };
    }).toList();
    await prefs.setString('nearby_errands', jsonEncode(items));
    await prefs.setInt('nearby_count', results.length);
  } catch (_) {}
}

/// 탐색에 쓸 현재 좌표. null 이면 위치 권한·GPS 필요.
final requestBrowseCoordsProvider =
    StateProvider<({double latitude, double longitude})?>((ref) => null);

/// pull-to-refresh·필터 적용 시 증가.
final requestBrowseRefreshTickProvider = StateProvider<int>((ref) => 0);

class RequestBrowseLocationRequired implements Exception {
  const RequestBrowseLocationRequired();
}
