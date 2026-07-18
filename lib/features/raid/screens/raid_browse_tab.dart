import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/naver_map_support.dart';
import '../../../shared/widgets/ttm_empty_state.dart';
import '../models/exercise_matching_models.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';
import '../services/exercise_location_service.dart';
import '../widgets/raid_card.dart';

class RaidBrowseTab extends ConsumerStatefulWidget {
  const RaidBrowseTab({super.key});

  @override
  ConsumerState<RaidBrowseTab> createState() => _RaidBrowseTabState();
}

class _RaidBrowseTabState extends ConsumerState<RaidBrowseTab> {
  String _exercise = 'all';
  String _price = 'all';
  int? _distanceMeters;
  bool _showMap = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  final List<Raid> _extraRaids = [];

  @override
  Widget build(BuildContext context) {
    final raids = ref.watch(raidBrowseProvider);
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _extraRaids.clear();
          _hasMore = true;
        });
        ref.invalidate(raidBrowseProvider);
        await ref.read(raidBrowseProvider.future);
      },
      child: raids.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(TtmSpacing.lg),
          children: [
            const SizedBox(height: 120),
            TtmEmptyState(
              title: error is ExerciseLocationException
                  ? '위치 확인이 필요해요'
                  : '레이드를 불러오지 못했어요',
              subtitle: error is ExerciseLocationException
                  ? exerciseLocationMessage(error.reason)
                  : '아래로 당겨 다시 확인해 주세요.',
              iconAsset: 'assets/icons/bolt.svg',
            ),
          ],
        ),
        data: (items) {
          final baseIds = items.map((item) => item.id).toSet();
          final displayItems = <Raid>[
            ...items,
            ..._extraRaids.where((item) => !baseIds.contains(item.id)),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.md,
              TtmSpacing.lg,
              120,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '가까운 곳에서\n함께 운동해요',
                      style: TtmTypography.display.copyWith(fontSize: 24),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: _showMap ? '목록만 보기' : '지도 보기',
                    onPressed: () => setState(() => _showMap = !_showMap),
                    icon: Icon(
                      _showMap ? Icons.view_list_rounded : Icons.map_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TtmSpacing.md),
              if (_showMap) ...[
                _RaidMap(raids: displayItems),
                const SizedBox(height: TtmSpacing.md),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in const <int?, String>{
                      null: '거리 전체',
                      1000: '1km',
                      3000: '3km',
                      5000: '5km',
                    }.entries) ...[
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _distanceMeters == entry.key,
                        onSelected: (_) => _setDistance(entry.key),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: TtmSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in const {
                      'all': '전체 운동',
                      'running': '러닝',
                      'walking': '걷기',
                      'badminton': '배드민턴',
                      'basketball': '농구',
                      'fitness': '기초 체력',
                    }.entries) ...[
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _exercise == entry.key,
                        onSelected: (_) => _setExercise(entry.key),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: TtmSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('전체')),
                  ButtonSegment(value: 'free', label: Text('무료')),
                  ButtonSegment(value: 'paid', label: Text('운영자 레이드')),
                ],
                selected: {_price},
                onSelectionChanged: (value) => _setPrice(value.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: TtmSpacing.lg),
              Text(
                '${displayItems.length}개의 레이드',
                style: TtmTypography.title.copyWith(fontSize: 17),
              ),
              const SizedBox(height: TtmSpacing.sm),
              if (displayItems.isEmpty)
                const TtmEmptyState(
                  title: '조건에 맞는 레이드가 없어요',
                  subtitle: '다른 운동이나 참가 조건을 선택해 보세요.',
                  iconAsset: 'assets/icons/search.svg',
                )
              else
                for (final raid in displayItems) ...[
                  RaidCard(
                    raid: raid,
                    onTap: () =>
                        context.push('${AppRoutes.raidRoot}/${raid.id}'),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                ],
              if (displayItems.isNotEmpty && _hasMore) ...[
                const SizedBox(height: TtmSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _loadingMore
                      ? null
                      : () => _loadMore(displayItems),
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_loadingMore ? '불러오는 중' : '레이드 더 보기'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _setDistance(int? value) {
    setState(() {
      _distanceMeters = value;
      _extraRaids.clear();
      _hasMore = true;
    });
    ref.read(raidBrowseQueryProvider.notifier).state = RaidBrowseQuery(
      radiusMeters: value,
      exerciseType: _exercise,
      feeType: _price,
    );
  }

  void _setExercise(String value) {
    setState(() {
      _exercise = value;
      _extraRaids.clear();
      _hasMore = true;
    });
    ref.read(raidBrowseQueryProvider.notifier).state = RaidBrowseQuery(
      radiusMeters: _distanceMeters,
      exerciseType: value,
      feeType: _price,
    );
  }

  void _setPrice(String value) {
    setState(() {
      _price = value;
      _extraRaids.clear();
      _hasMore = true;
    });
    ref.read(raidBrowseQueryProvider.notifier).state = RaidBrowseQuery(
      radiusMeters: _distanceMeters,
      exerciseType: _exercise,
      feeType: value,
    );
  }

  Future<void> _loadMore(List<Raid> current) async {
    if (_loadingMore || current.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      ExerciseLocationSnapshot? location;
      try {
        location = await ref
            .read(exerciseLocationServiceProvider)
            .current(request: _distanceMeters != null);
      } on ExerciseLocationException {
        if (_distanceMeters != null) rethrow;
      }
      final last = current.last;
      final next = await ref
          .read(raidRepositoryProvider)
          .fetchRaids(
            latitude: location?.latitude,
            longitude: location?.longitude,
            radiusM: _distanceMeters,
            exerciseType: _exercise,
            feeType: _price,
            cursorStartsAt: last.startsAt,
            cursorId: last.id,
          );
      if (!mounted) return;
      final known = current.map((item) => item.id).toSet();
      setState(() {
        _extraRaids.addAll(next.where((item) => !known.contains(item.id)));
        _hasMore = next.length == 30;
      });
    } on ExerciseLocationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exerciseLocationMessage(error.reason))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _RaidMap extends StatefulWidget {
  const _RaidMap({required this.raids});
  final List<Raid> raids;

  @override
  State<_RaidMap> createState() => _RaidMapState();
}

class _RaidMapState extends State<_RaidMap> {
  NaverMapController? _controller;
  final Map<String, NMarker> _markers = {};

  @override
  void didUpdateWidget(covariant _RaidMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raids != widget.raids) unawaited(_syncMarkers());
  }

  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null) return;
    for (final marker in _markers.values) {
      try {
        await controller.deleteOverlay(marker.info);
      } catch (_) {}
    }
    _markers.clear();
    for (final raid in widget.raids) {
      if (raid.venue.latitude == 0 || raid.venue.longitude == 0) continue;
      final marker = NMarker(
        id: 'raid_${raid.id}',
        position: NLatLng(raid.venue.latitude, raid.venue.longitude),
        caption: NOverlayCaption(text: exerciseLabel(raid.exerciseType)),
      );
      _markers[raid.id] = marker;
      await controller.addOverlay(marker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!ttmSupportsEmbeddedNaverMap || widget.raids.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Icon(Icons.map_outlined, size: 44, color: TtmColors.primary),
        ),
      );
    }
    final first = widget.raids.first.venue;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: NaverMap(
          forceGesture: true,
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(first.latitude, first.longitude),
              zoom: 13.5,
            ),
            rotationGesturesEnable: false,
            tiltGesturesEnable: false,
          ),
          onMapReady: (controller) async {
            _controller = controller;
            await _syncMarkers();
          },
        ),
      ),
    );
  }
}
