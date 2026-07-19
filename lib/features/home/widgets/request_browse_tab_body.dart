import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../match/models/match_request.dart';
import '../../../core/widget/ttm_widget_sync_service.dart';
import '../../../core/utils/concurrent_limit_messages.dart';
import '../../../core/utils/pedestrian_location.dart';
import '../../../core/utils/restriction_error_message.dart';
import '../../../data/models/user_restriction.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/worker_activity_providers.dart';
import '../../../shared/widgets/ttm_feed_skeleton.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../../shared/widgets/user_restriction_notice.dart';
import '../../match/models/request_task_type.dart';
import '../../match/providers/match_providers.dart';
import '../../match/providers/request_browse_providers.dart';
import 'general_request_post_card.dart';
import 'ttm_dense_task_card.dart';

/// 요청 탭 — 활동 ON 없이 반경·카테고리·액수 필터로 open 요청 탐색.
class RequestBrowseTabBody extends ConsumerStatefulWidget {
  const RequestBrowseTabBody({super.key});

  @override
  ConsumerState<RequestBrowseTabBody> createState() =>
      _RequestBrowseTabBodyState();
}

class _RequestBrowseTabBodyState extends ConsumerState<RequestBrowseTabBody> {
  final Set<String> _accepting = {};
  final _tagSearchController = TextEditingController();
  bool _locating = false;
  bool _filterOpen = false;

  static const _distanceOptions = [
    (500, '500m'),
    (1000, '1km'),
    (2000, '2km'),
    (5000, '5km'),
  ];

  static const _maxRewardOptions = [
    (null, '상한 없음'),
    (10000, '~₩10,000'),
    (30000, '~₩30,000'),
    (50000, '~₩50,000'),
  ];

  static const _minRewardOptions = [
    (null, '전체'),
    (5000, '₩5,000+'),
    (10000, '₩10,000+'),
    (30000, '₩30,000+'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureLocation(refresh: true));
    });
  }

  @override
  void dispose() {
    _tagSearchController.dispose();
    super.dispose();
  }

  Future<void> _ensureLocation({bool refresh = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await TtmPedestrianLocation.obtainPosition();
      if (!mounted) return;
      if (pos == null) {
        ref.read(requestBrowseCoordsProvider.notifier).state = null;
      } else {
        ref.read(requestBrowseCoordsProvider.notifier).state = (
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        if (refresh) {
          ref.read(requestBrowseRefreshTickProvider.notifier).state++;
        }
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _refresh() async {
    await _ensureLocation(refresh: true);
  }

  void _bumpRefresh() {
    ref.read(requestBrowseRefreshTickProvider.notifier).state++;
  }

  static String? _normalizeTag(String raw) {
    final tag = raw.replaceAll('#', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (tag.isEmpty) return null;
    return tag.length > 16 ? tag.substring(0, 16) : tag;
  }

  Future<void> _accept(String requestId) async {
    if (_accepting.contains(requestId)) return;
    final filters = ref.read(requestBrowseFiltersProvider);
    setState(() => _accepting.add(requestId));
    try {
      final res = filters.matchingMode == 'general'
          ? await _applyGeneral(requestId)
          : await ref.read(matchingRepositoryProvider).acceptRequest(requestId);
      if (!mounted) return;
      if (res['ok'] == true) {
        if (filters.matchingMode == 'general') {
          final applicationId = res['application_id']?.toString();
          final alreadyApplied = res['already_applied'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                alreadyApplied
                    ? '이미 지원한 작업이에요. 기존 채팅으로 이동합니다.'
                    : '지원했어요. 채팅에서 조건과 ○○비를 협의해 주세요.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _bumpRefresh();
          ref.invalidate(myGeneralApplicationsProvider);
          ref.invalidate(requestBrowseResultsProvider);
          if (applicationId != null && applicationId.isNotEmpty) {
            context.push(
              '${AppRoutes.requestRoot}/$requestId/applications/$applicationId/chat',
            );
          }
          return;
        }
        await syncMatchedWorkerTracking(ref);
        if (!mounted) return;
        context.push('${AppRoutes.requestRoot}/$requestId/active');
      } else if (mounted) {
        final premium =
            ref.read(myProfileProvider).valueOrNull?.isPremium ?? false;
        final msg = acceptConcurrentLimitMessage(
          res['reason']?.toString(),
          isPremium: premium,
        );
        if (msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
        _bumpRefresh();
      }
    } catch (e) {
      if (mounted) {
        final restrictionMsg = restrictionErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restrictionMsg.isNotEmpty ? restrictionMsg : '수락 오류: $e',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting.remove(requestId));
    }
  }

  Future<Map<String, dynamic>> _applyGeneral(String requestId) async {
    final messageController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작업자 지원'),
        content: TextField(
          controller: messageController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '요청자에게 보낼 말',
            hintText: '가능한 시간, 경험, 확인할 내용을 적어주세요.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지원하기'),
          ),
        ],
      ),
    );
    final message = messageController.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messageController.dispose();
    });
    if (ok != true) {
      return <String, dynamic>{'ok': false, 'reason': 'cancelled'};
    }
    return ref
        .read(matchingRepositoryProvider)
        .applyGeneralRequest(
          requestId,
          initialMessage: message.isEmpty ? null : message,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final navBottom = MediaQuery.paddingOf(context).bottom;
    final filters = ref.watch(requestBrowseFiltersProvider);
    final async = ref.watch(requestBrowseResultsProvider);
    ref.listen(requestBrowseResultsProvider, (prev, next) {
      next.whenData((items) {
        unawaited(TtmWidgetSyncService.syncNearbyErrands(items));
      });
    });
    final restrictions =
        ref.watch(myActiveRestrictionsProvider).valueOrNull ?? const [];
    final workerBlocked = restrictions.blocksWorker;
    final ownPostsAsync = ref.watch(myOpenGeneralRequestsProvider);
    final appliedGeneral = ref.watch(myGeneralApplicationsProvider);
    final appliedApplicationIdsByRequest = <String, String>{
      for (final item in appliedGeneral.valueOrNull ?? const [])
        if (item.isPending && item.request.isOpen)
          item.requestId: item.applicationId,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const UserRestrictionNotice(onlyBlockingWorker: true, compact: true),
        if (workerBlocked) const SizedBox(height: TtmSpacing.md),
        _MatchingModeBar(
          mode: filters.matchingMode,
          onChanged: (mode) {
            ref.read(requestBrowseFiltersProvider.notifier).state = filters
                .copyWith(matchingMode: mode);
            _bumpRefresh();
          },
        ),
        _FilterToggleBar(
          open: _filterOpen,
          filters: filters,
          onToggle: () => setState(() => _filterOpen = !_filterOpen),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _filterOpen
              ? _FilterPanel(
                  filters: filters,
                  tagController: _tagSearchController,
                  locating: _locating,
                  showDistance: filters.matchingMode == 'quick',
                  onDistance: (m) {
                    ref.read(requestBrowseFiltersProvider.notifier).state =
                        filters.copyWith(maxDistanceM: m);
                    _bumpRefresh();
                  },
                  onToggleTaskType: (taskType) {
                    final next = Set<String>.from(filters.taskTypes);
                    if (next.contains(taskType)) {
                      next.remove(taskType);
                    } else {
                      next.add(taskType);
                    }
                    ref.read(requestBrowseFiltersProvider.notifier).state =
                        filters.copyWith(taskTypes: next);
                    _bumpRefresh();
                  },
                  onAddCustomTag: (tag) {
                    final normalized = _normalizeTag(tag);
                    if (normalized == null) return;
                    final next = Set<String>.from(filters.customTags)
                      ..add(normalized);
                    ref.read(requestBrowseFiltersProvider.notifier).state =
                        filters.copyWith(customTags: next);
                    _tagSearchController.clear();
                    _bumpRefresh();
                  },
                  onRemoveCustomTag: (tag) {
                    final next = Set<String>.from(filters.customTags)
                      ..remove(tag);
                    ref.read(requestBrowseFiltersProvider.notifier).state =
                        filters.copyWith(customTags: next);
                    _bumpRefresh();
                  },
                  onMinReward: (v) {
                    ref
                        .read(requestBrowseFiltersProvider.notifier)
                        .state = filters.copyWith(
                      minReward: v,
                      clearMinReward: v == null,
                    );
                    _bumpRefresh();
                  },
                  onMaxReward: (v) {
                    ref
                        .read(requestBrowseFiltersProvider.notifier)
                        .state = filters.copyWith(
                      maxReward: v,
                      clearMaxReward: v == null,
                    );
                    _bumpRefresh();
                  },
                  onTaskMinutes: (min, max) {
                    ref
                        .read(requestBrowseFiltersProvider.notifier)
                        .state = filters.copyWith(
                      minTaskMinutes: min,
                      maxTaskMinutes: max,
                      clearMinTaskMinutes: min == null,
                      clearMaxTaskMinutes: max == null,
                    );
                    _bumpRefresh();
                  },
                  onRetryLocation: () =>
                      unawaited(_ensureLocation(refresh: true)),
                )
              : const SizedBox.shrink(),
        ),
        if (filters.matchingMode == 'general')
          ownPostsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (ownPosts) {
              if (ownPosts.isEmpty) return const SizedBox.shrink();
              return Material(
                color: colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TtmSpacing.lg,
                        TtmSpacing.sm,
                        TtmSpacing.lg,
                        TtmSpacing.xs,
                      ),
                      child: Text(
                        '내 게시글',
                        style: TtmTypography.title.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final post in ownPosts.take(3)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TtmSpacing.lg,
                        ),
                        child: _OwnGeneralPostTile(request: post),
                      ),
                      const SizedBox(height: TtmSpacing.xs),
                    ],
                    const Divider(height: 1),
                  ],
                ),
              );
            },
          ),
        Expanded(
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(TtmSpacing.lg),
              child: TtmFeedSkeleton(rowCount: 5),
            ),
            error: (e, _) {
              if (e is RequestBrowseLocationRequired) {
                return _LocationEmpty(
                  busy: _locating,
                  onRetry: () => unawaited(_ensureLocation(refresh: true)),
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(TtmSpacing.xl),
                  child: Text(
                    '불러오지 못했어요.\n$e',
                    textAlign: TextAlign.center,
                    style: TtmTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
            data: (list) {
              if (list.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: colors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(TtmSpacing.xl),
                    children: [
                      const SizedBox(height: 28),
                      _BrowseEmptySuggestions(
                        filters: filters,
                        onWidenRadius: filters.maxDistanceM >= 5000
                            ? null
                            : () {
                                ref
                                    .read(requestBrowseFiltersProvider.notifier)
                                    .state = filters.copyWith(
                                  maxDistanceM: 5000,
                                );
                                _bumpRefresh();
                              },
                        onClearReward:
                            filters.minReward == null &&
                                filters.maxReward == null
                            ? null
                            : () {
                                ref
                                    .read(requestBrowseFiltersProvider.notifier)
                                    .state = filters.copyWith(
                                  clearMinReward: true,
                                  clearMaxReward: true,
                                );
                                _bumpRefresh();
                              },
                        onOpenFilters: () => setState(() => _filterOpen = true),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                color: colors.primary,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    TtmSpacing.lg,
                    TtmSpacing.sm,
                    TtmSpacing.lg,
                    navBottom + 24,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: TtmSpacing.sm),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    if (filters.matchingMode == 'general') {
                      final appliedApplicationId =
                          n.myApplicationId ??
                          appliedApplicationIdsByRequest[n.requestId];
                      return GeneralRequestPostCard(
                        notification: n,
                        busy: _accepting.contains(n.requestId),
                        applied:
                            n.hasMyGeneralApplication ||
                            appliedApplicationId != null,
                        onTap: () => context.push(
                          '${AppRoutes.requestRoot}/${n.requestId}/general',
                        ),
                        onApply: appliedApplicationId == null
                            ? () => _accept(n.requestId)
                            : () => context.push(
                                '${AppRoutes.requestRoot}/${n.requestId}/applications/$appliedApplicationId/chat',
                              ),
                      );
                    }
                    return TtmDenseTaskCard(
                      notification: n,
                      busy: _accepting.contains(n.requestId),
                      actionLabel: filters.matchingMode == 'general'
                          ? '지원하기'
                          : null,
                      onAccept: () => _accept(n.requestId),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MatchingModeBar extends StatelessWidget {
  const _MatchingModeBar({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.lg,
          TtmSpacing.sm,
          TtmSpacing.lg,
          TtmSpacing.xs,
        ),
        child: SegmentedButton<String>(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: TtmColors.primaryLight,
            selectedForegroundColor: TtmColors.deepGreen,
          ),
          segments: const [
            ButtonSegment(
              value: 'quick',
              icon: Icon(Icons.radar_rounded),
              label: Text('빠른 매칭'),
            ),
            ButtonSegment(
              value: 'general',
              icon: Icon(Icons.forum_rounded),
              label: Text('일반 매칭'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (next) => onChanged(next.first),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.filters,
    required this.tagController,
    required this.locating,
    required this.showDistance,
    required this.onDistance,
    required this.onToggleTaskType,
    required this.onAddCustomTag,
    required this.onRemoveCustomTag,
    required this.onMinReward,
    required this.onMaxReward,
    required this.onTaskMinutes,
    required this.onRetryLocation,
  });

  final RequestBrowseFilters filters;
  final TextEditingController tagController;
  final bool locating;
  final bool showDistance;
  final ValueChanged<int> onDistance;
  final ValueChanged<String> onToggleTaskType;
  final ValueChanged<String> onAddCustomTag;
  final ValueChanged<String> onRemoveCustomTag;
  final ValueChanged<int?> onMinReward;
  final ValueChanged<int?> onMaxReward;
  final void Function(int? minMinutes, int? maxMinutes) onTaskMinutes;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.lg,
          TtmSpacing.sm,
          TtmSpacing.lg,
          TtmSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDistance) ...[
              Row(
                children: [
                  Text(
                    '탐색 반경',
                    style: TtmTypography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (locating)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: onRetryLocation,
                      icon: const Icon(Icons.my_location_outlined, size: 16),
                      label: const Text('위치 갱신'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: TtmTypography.label.copyWith(fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TtmSpacing.xs),
              _ChipRow(
                children: [
                  for (final (m, label)
                      in _RequestBrowseTabBodyState._distanceOptions)
                    _FilterChip(
                      label: label,
                      selected: filters.maxDistanceM == m,
                      onTap: () => onDistance(m),
                    ),
                ],
              ),
              const SizedBox(height: TtmSpacing.sm),
            ],
            Text(
              '작업 유형',
              style: TtmTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TtmSpacing.xs),
            _ChipRow(
              children: [
                for (final type in RequestTaskType.values)
                  _FilterChip(
                    label: type.label,
                    selected: filters.taskTypes.contains(type.id),
                    onTap: () => onToggleTaskType(type.id),
                  ),
              ],
            ),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              '태그 검색',
              style: TtmTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TtmSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tagController,
                    minLines: 1,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: onAddCustomTag,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '예: 편의점, 강아지, 서류',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: TtmSpacing.xs),
                FilledButton.tonal(
                  onPressed: () => onAddCustomTag(tagController.text),
                  child: const Text('추가'),
                ),
              ],
            ),
            if (filters.customTags.isNotEmpty) ...[
              const SizedBox(height: TtmSpacing.xs),
              Wrap(
                spacing: TtmSpacing.xs,
                runSpacing: TtmSpacing.xs,
                children: [
                  for (final tag in filters.customTags)
                    InputChip(
                      label: Text('#$tag'),
                      onDeleted: () => onRemoveCustomTag(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: TtmSpacing.sm),
            Text(
              '최소 보상',
              style: TtmTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TtmSpacing.xs),
            _ChipRow(
              children: [
                for (final (v, label)
                    in _RequestBrowseTabBodyState._minRewardOptions)
                  _FilterChip(
                    label: label,
                    selected: filters.minReward == v,
                    onTap: () => onMinReward(v),
                  ),
              ],
            ),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              '최대 보상',
              style: TtmTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TtmSpacing.xs),
            _ChipRow(
              children: [
                for (final (v, label)
                    in _RequestBrowseTabBodyState._maxRewardOptions)
                  _FilterChip(
                    label: label,
                    selected: filters.maxReward == v,
                    onTap: () => onMaxReward(v),
                  ),
              ],
            ),
            const SizedBox(height: TtmSpacing.sm),
            _DurationRangeFilter(
              minMinutes: filters.minTaskMinutes,
              maxMinutes: filters.maxTaskMinutes,
              onChanged: onTaskMinutes,
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationRangeFilter extends StatelessWidget {
  const _DurationRangeFilter({
    required this.minMinutes,
    required this.maxMinutes,
    required this.onChanged,
  });

  static const int _min = 5;
  static const int _max = 720;
  static const int _step = 5;

  final int? minMinutes;
  final int? maxMinutes;
  final void Function(int? minMinutes, int? maxMinutes) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final start = (minMinutes ?? _min).clamp(_min, _max);
    final end = (maxMinutes ?? _max).clamp(_min, _max);
    final normalizedStart = start <= end ? start : end;
    final normalizedEnd = end >= start ? end : start;
    final active = minMinutes != null || maxMinutes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '예상 소요 시간',
              style: TtmTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              active
                  ? '${_minutesLabel(normalizedStart)}~${_minutesLabel(normalizedEnd)}'
                  : '전체',
              style: TtmTypography.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            if (active) ...[
              const SizedBox(width: TtmSpacing.xs),
              InkWell(
                borderRadius: BorderRadius.circular(TtmRadius.pill),
                onTap: () => onChanged(null, null),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        RangeSlider(
          min: _min.toDouble(),
          max: _max.toDouble(),
          divisions: (_max - _min) ~/ _step,
          values: RangeValues(
            normalizedStart.toDouble(),
            normalizedEnd.toDouble(),
          ),
          onChanged: (values) {
            final nextMin = _snap(values.start);
            final nextMax = _snap(values.end);
            onChanged(
              nextMin <= _min ? null : nextMin,
              nextMax >= _max ? null : nextMax,
            );
          },
        ),
      ],
    );
  }

  static int _snap(double value) => (value / _step).round() * _step;

  static String _minutesLabel(int minutes) {
    if (minutes < 60) return '$minutes분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }
}

class _FilterToggleBar extends StatelessWidget {
  const _FilterToggleBar({
    required this.open,
    required this.filters,
    required this.onToggle,
  });

  final bool open;
  final RequestBrowseFilters filters;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final distanceLabel = _RequestBrowseTabBodyState._distanceOptions
        .firstWhere(
          (o) => o.$1 == filters.maxDistanceM,
          orElse: () => _RequestBrowseTabBodyState._distanceOptions.first,
        )
        .$2;
    final taskTypeCount = filters.taskTypes.length;
    final tagCount = filters.customTags.length;
    final hasReward = filters.minReward != null || filters.maxReward != null;
    final hasTaskDuration =
        filters.minTaskMinutes != null || filters.maxTaskMinutes != null;

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TtmSpacing.lg,
            vertical: TtmSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: open ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: TtmSpacing.xs),
              Text(
                '필터',
                style: TtmTypography.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: open ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              _SummaryChip(distanceLabel),
              if (taskTypeCount > 0) ...[
                const SizedBox(width: TtmSpacing.xs),
                _SummaryChip('유형 $taskTypeCount'),
              ],
              if (tagCount > 0) ...[
                const SizedBox(width: TtmSpacing.xs),
                _SummaryChip('태그 $tagCount'),
              ],
              if (hasReward) ...[
                const SizedBox(width: TtmSpacing.xs),
                _SummaryChip('보상 조건'),
              ],
              if (hasTaskDuration) ...[
                const SizedBox(width: TtmSpacing.xs),
                _SummaryChip('시간 조건'),
              ],
              const Spacer(),
              AnimatedRotation(
                turns: open ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TtmRadius.sm),
      ),
      child: Text(
        label,
        style: TtmTypography.label.copyWith(
          fontSize: 12,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: TtmSpacing.xs),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TtmTypography.label.copyWith(
        fontSize: 12,
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
      ),
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide(
        color: selected
            ? colors.primary.withValues(alpha: 0.4)
            : colors.outlineVariant.withValues(alpha: 0.5),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TtmRadius.sm),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _BrowseEmptySuggestions extends StatefulWidget {
  const _BrowseEmptySuggestions({
    required this.filters,
    required this.onWidenRadius,
    required this.onClearReward,
    required this.onOpenFilters,
  });

  final RequestBrowseFilters filters;
  final VoidCallback? onWidenRadius;
  final VoidCallback? onClearReward;
  final VoidCallback onOpenFilters;

  @override
  State<_BrowseEmptySuggestions> createState() =>
      _BrowseEmptySuggestionsState();
}

class _BrowseEmptySuggestionsState extends State<_BrowseEmptySuggestions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasTypeFilter = widget.filters.taskTypes.isNotEmpty;
    final hasRewardFilter =
        widget.filters.minReward != null || widget.filters.maxReward != null;
    final hasTimeFilter =
        widget.filters.minTaskMinutes != null ||
        widget.filters.maxTaskMinutes != null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: TtmTierCard(
        tier: TtmCardTier.feed,
        padding: const EdgeInsets.all(TtmSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.09),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(
                            alpha: 0.08 + _pulse.value * 0.12,
                          ),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.travel_explore_rounded,
                      color: colors.primary,
                      size: 28,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: TtmSpacing.lg),
            Text(
              '조건에 맞는 ○○이 없어요',
              textAlign: TextAlign.center,
              style: TtmTypography.title.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: TtmSpacing.xs),
            Text(
              _emptyHint(hasTypeFilter, hasRewardFilter, hasTimeFilter),
              textAlign: TextAlign.center,
              style: TtmTypography.body.copyWith(
                fontSize: 13,
                height: 1.45,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TtmSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: TtmSpacing.sm,
              runSpacing: TtmSpacing.sm,
              children: [
                if (widget.onWidenRadius != null)
                  _SuggestionButton(
                    icon: Icons.radar_rounded,
                    label: '5km까지 보기',
                    onTap: widget.onWidenRadius!,
                  ),
                if (widget.onClearReward != null)
                  _SuggestionButton(
                    icon: Icons.payments_outlined,
                    label: '보상 조건 풀기',
                    onTap: widget.onClearReward!,
                  ),
                _SuggestionButton(
                  icon: Icons.tune_rounded,
                  label: '필터 다시 보기',
                  onTap: widget.onOpenFilters,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _emptyHint(
    bool hasTypeFilter,
    bool hasRewardFilter,
    bool hasTimeFilter,
  ) {
    if (hasTypeFilter || hasRewardFilter || hasTimeFilter) {
      return '필터가 조금 좁을 수 있어요. 조건을 풀면 근처 요청을 더 넓게 볼 수 있습니다.';
    }
    return '지금은 조용한 시간이에요. 화면을 아래로 당기면 새 요청을 다시 확인합니다.';
  }
}

class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary.withValues(alpha: 0.28)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TtmRadius.pill),
        ),
        textStyle: TtmTypography.label.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LocationEmpty extends StatelessWidget {
  const _LocationEmpty({required this.busy, required this.onRetry});

  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TtmSpacing.xl),
      children: [
        const SizedBox(height: 64),
        Icon(Icons.location_off_outlined, size: 48, color: colors.outline),
        const SizedBox(height: TtmSpacing.lg),
        Text(
          '위치 권한이 필요해요',
          textAlign: TextAlign.center,
          style: TtmTypography.title.copyWith(fontSize: 16),
        ),
        const SizedBox(height: TtmSpacing.sm),
        Text(
          '주변 ○○을 찾으려면\n현재 위치를 허용해 주세요.',
          textAlign: TextAlign.center,
          style: TtmTypography.body.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: TtmSpacing.lg),
        Center(
          child: FilledButton(
            onPressed: busy ? null : onRetry,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('위치 허용 후 다시 시도'),
          ),
        ),
      ],
    );
  }
}

class _OwnGeneralPostTile extends StatelessWidget {
  const _OwnGeneralPostTile({required this.request});

  final MatchRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(TtmRadius.sm),
      onTap: () =>
          context.push('${AppRoutes.requestRoot}/${request.id}/general'),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TtmSpacing.md,
          vertical: TtmSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(TtmRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TtmTypography.title.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TtmTypography.body.copyWith(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TtmSpacing.sm),
            Text(
              '${NumberFormat.decimalPattern('ko').format(request.reward)}원',
              style: TtmTypography.moneyDisplay.copyWith(
                fontSize: 13,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: TtmSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
