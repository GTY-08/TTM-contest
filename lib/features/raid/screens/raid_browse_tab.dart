import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/naver_map_support.dart';
import '../../../shared/widgets/ttm_empty_state.dart';
import '../../match/widgets/map_gesture_guard.dart';
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
  int? _distanceMeters;
  bool _showMap = true;
  bool _locationLoading = false;
  bool _placeSearchBusy = false;
  ExerciseLocationSnapshot? _mapLocation;
  RaidPlaceSearchResult? _searchedPlace;
  final TextEditingController _placeSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadMapLocation(showMessage: false));
    });
  }

  @override
  void dispose() {
    _placeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raids = ref.watch(raidBrowseProvider);
    return RefreshIndicator(
      onRefresh: () async {
        await _loadMapLocation(showMessage: false);
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
          final displayItems = items;
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
              TextField(
                controller: _placeSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchPlace(),
                decoration: InputDecoration(
                  hintText: '주소나 장소 검색',
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: _placeSearchBusy
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: '검색',
                          onPressed: _searchPlace,
                          icon: const Icon(Icons.search_rounded),
                        ),
                ),
              ),
              if (_searchedPlace != null) ...[
                const SizedBox(height: 6),
                Text(
                  '검색 위치 · ${_searchedPlace!.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TtmTypography.label.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: TtmSpacing.md),
              if (_showMap) ...[
                _RaidMap(
                  raids: displayItems,
                  currentLocation: _mapLocation,
                  searchedPlace: _searchedPlace,
                  locationLoading: _locationLoading,
                  onRequestLocation: () => _loadMapLocation(showMessage: true),
                  onRaidTap: _showRaidPreview,
                ),
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
            ],
          );
        },
      ),
    );
  }

  void _setDistance(int? value) {
    setState(() => _distanceMeters = value);
    ref.read(raidBrowseQueryProvider.notifier).state = RaidBrowseQuery(
      radiusMeters: value,
      exerciseType: _exercise,
    );
  }

  void _setExercise(String value) {
    setState(() => _exercise = value);
    ref.read(raidBrowseQueryProvider.notifier).state = RaidBrowseQuery(
      radiusMeters: _distanceMeters,
      exerciseType: value,
    );
  }

  Future<void> _showRaidPreview(Raid raid) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.lg,
          TtmSpacing.sm,
          TtmSpacing.lg,
          TtmSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('레이드 정보', style: TtmTypography.title.copyWith(fontSize: 20)),
            const SizedBox(height: TtmSpacing.md),
            RaidCard(
              raid: raid,
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('${AppRoutes.raidRoot}/${raid.id}');
              },
            ),
            const SizedBox(height: TtmSpacing.md),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push('${AppRoutes.raidRoot}/${raid.id}');
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('자세히 보기'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _loadMapLocation({required bool showMessage}) async {
    if (_locationLoading) return;
    setState(() => _locationLoading = true);
    try {
      final location = await ref
          .read(exerciseLocationServiceProvider)
          .current();
      if (!mounted) return;
      setState(() => _mapLocation = location);
      ref.invalidate(raidBrowseProvider);
    } on ExerciseLocationException catch (error) {
      if (mounted && showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exerciseLocationMessage(error.reason))),
        );
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _searchPlace() async {
    final query = _placeSearchController.text.trim();
    if (query.length < 2) {
      _showMessage('검색어를 두 글자 이상 입력해 주세요.');
      return;
    }
    if (_placeSearchBusy) return;
    setState(() => _placeSearchBusy = true);
    try {
      final results = await ref
          .read(raidRepositoryProvider)
          .searchPlaces(query);
      if (!mounted) return;
      if (results.isEmpty) {
        _showMessage('검색 결과가 없어요. 다른 단어로 찾아보세요.');
        return;
      }
      final sorted = [...results]
        ..sort(
          (a, b) => _distanceFromSearchOrigin(
            a,
          ).compareTo(_distanceFromSearchOrigin(b)),
        );
      final selected = sorted.length == 1
          ? sorted.first
          : await _showPlaceResults(sorted);
      if (selected == null || !mounted) return;
      setState(() {
        _searchedPlace = selected;
        _showMap = true;
      });
      _showMessage('${selected.label}(으)로 지도를 이동했어요.');
    } catch (_) {
      if (mounted) _showMessage('장소 검색에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _placeSearchBusy = false);
    }
  }

  double _distanceFromSearchOrigin(RaidPlaceSearchResult place) {
    final location = _mapLocation;
    if (location == null) return 0;
    return Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      place.latitude,
      place.longitude,
    );
  }

  Future<RaidPlaceSearchResult?> _showPlaceResults(
    List<RaidPlaceSearchResult> results,
  ) {
    return showModalBottomSheet<RaidPlaceSearchResult>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.sm,
              TtmSpacing.lg,
              TtmSpacing.lg,
            ),
            itemCount: results.length + 1,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: TtmSpacing.md),
                  child: Text(
                    '검색 결과',
                    style: TtmTypography.title.copyWith(fontSize: 20),
                  ),
                );
              }
              final place = results[index - 1];
              final distance = _distanceFromSearchOrigin(place);
              final distanceText = _mapLocation == null
                  ? ''
                  : distance >= 1000
                  ? '${(distance / 1000).toStringAsFixed(1)}km'
                  : '${distance.round()}m';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    place.source == 'local'
                        ? Icons.storefront_rounded
                        : Icons.location_on_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  place.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (place.address.isNotEmpty) place.address,
                    if (distanceText.isNotEmpty) distanceText,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, place),
              );
            },
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _RaidMap extends StatefulWidget {
  const _RaidMap({
    required this.raids,
    required this.currentLocation,
    required this.searchedPlace,
    required this.locationLoading,
    required this.onRequestLocation,
    required this.onRaidTap,
  });

  final List<Raid> raids;
  final ExerciseLocationSnapshot? currentLocation;
  final RaidPlaceSearchResult? searchedPlace;
  final bool locationLoading;
  final Future<void> Function() onRequestLocation;
  final ValueChanged<Raid> onRaidTap;

  @override
  State<_RaidMap> createState() => _RaidMapState();
}

class _RaidMapState extends State<_RaidMap> {
  NaverMapController? _controller;
  final Map<String, NMarker> _markers = {};
  double _zoom = 14.5;

  static const _fallback = NLatLng(37.5665, 126.9780);

  @override
  void didUpdateWidget(covariant _RaidMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.currentLocation?.latitude !=
            widget.currentLocation?.latitude ||
        oldWidget.currentLocation?.longitude !=
            widget.currentLocation?.longitude;
    final searchChanged =
        oldWidget.searchedPlace?.latitude != widget.searchedPlace?.latitude ||
        oldWidget.searchedPlace?.longitude != widget.searchedPlace?.longitude;
    if (oldWidget.raids != widget.raids || locationChanged || searchChanged) {
      unawaited(_syncMarkers());
    }
    if (searchChanged && widget.searchedPlace != null) {
      unawaited(_moveToSearchedPlace());
      return;
    }
    if (locationChanged && widget.currentLocation != null) {
      unawaited(_moveToCurrentLocation());
    }
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
      marker.setOnTapListener((_) => widget.onRaidTap(raid));
      _markers[raid.id] = marker;
      try {
        await controller.addOverlay(marker);
      } catch (_) {}
    }
    final location = widget.currentLocation;
    if (location != null) {
      final marker = NMarker(
        id: 'current_location',
        position: NLatLng(location.latitude, location.longitude),
        caption: const NOverlayCaption(text: '내 위치'),
      );
      _markers['current_location'] = marker;
      try {
        await controller.addOverlay(marker);
      } catch (_) {}
    }
    final searchedPlace = widget.searchedPlace;
    if (searchedPlace != null) {
      final marker = NMarker(
        id: 'searched_place',
        position: NLatLng(searchedPlace.latitude, searchedPlace.longitude),
        caption: NOverlayCaption(text: searchedPlace.label),
      );
      _markers['searched_place'] = marker;
      try {
        await controller.addOverlay(marker);
      } catch (_) {}
    }
  }

  NLatLng get _initialTarget {
    final searchedPlace = widget.searchedPlace;
    if (searchedPlace != null) {
      return NLatLng(searchedPlace.latitude, searchedPlace.longitude);
    }
    final location = widget.currentLocation;
    if (location != null) return NLatLng(location.latitude, location.longitude);
    for (final raid in widget.raids) {
      if (raid.venue.latitude != 0 && raid.venue.longitude != 0) {
        return NLatLng(raid.venue.latitude, raid.venue.longitude);
      }
    }
    return _fallback;
  }

  Future<void> _moveToCurrentLocation() async {
    final controller = _controller;
    final location = widget.currentLocation;
    if (controller == null || location == null) return;
    _zoom = 15.5;
    try {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(location.latitude, location.longitude),
          zoom: _zoom,
        ),
      );
    } catch (_) {}
  }

  Future<void> _moveToSearchedPlace() async {
    final controller = _controller;
    final place = widget.searchedPlace;
    if (controller == null || place == null) return;
    _zoom = 17;
    try {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(place.latitude, place.longitude),
          zoom: _zoom,
        ),
      );
    } catch (_) {}
  }

  Future<void> _zoomBy(double delta) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final camera = await controller.getCameraPosition();
      _zoom = (camera.zoom + delta).clamp(10, 20);
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: camera.target, zoom: _zoom),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!ttmSupportsEmbeddedNaverMap) {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MapGestureGuard(
              child: NaverMap(
                forceGesture: true,
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: _initialTarget,
                    zoom: _zoom,
                  ),
                  scrollGesturesEnable: true,
                  zoomGesturesEnable: true,
                  rotationGesturesEnable: false,
                  tiltGesturesEnable: false,
                  consumeSymbolTapEvents: false,
                ),
                onMapReady: (controller) async {
                  _controller = controller;
                  await _syncMarkers();
                  if (widget.searchedPlace != null) {
                    await _moveToSearchedPlace();
                  } else {
                    await _moveToCurrentLocation();
                  }
                },
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapControlButton(
                    tooltip: '내 위치',
                    onTap: widget.locationLoading
                        ? null
                        : () async {
                            if (widget.currentLocation == null) {
                              await widget.onRequestLocation();
                            } else {
                              await _moveToCurrentLocation();
                            }
                          },
                    child: widget.locationLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 21),
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    tooltip: '확대',
                    onTap: () => _zoomBy(1),
                    child: const Icon(Icons.add_rounded, size: 22),
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    tooltip: '축소',
                    onTap: () => _zoomBy(-1),
                    child: const Icon(Icons.remove_rounded, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final Future<void> Function()? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surface.withValues(alpha: 0.94),
        elevation: 2,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}
