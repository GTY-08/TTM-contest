import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/naver_map_support.dart';

class QuickMatchLiveMap extends StatefulWidget {
  const QuickMatchLiveMap({
    super.key,
    required this.meetingLatitude,
    required this.meetingLongitude,
    required this.myLatitude,
    required this.myLongitude,
    required this.partnerLatitude,
    required this.partnerLongitude,
    required this.partnerLabel,
    this.height = 260,
  });

  final double? meetingLatitude;
  final double? meetingLongitude;
  final double? myLatitude;
  final double? myLongitude;
  final double? partnerLatitude;
  final double? partnerLongitude;
  final String partnerLabel;
  final double height;

  @override
  State<QuickMatchLiveMap> createState() => _QuickMatchLiveMapState();
}

class _QuickMatchLiveMapState extends State<QuickMatchLiveMap> {
  NaverMapController? _controller;
  NMarker? _meetingMarker;
  NMarker? _myMarker;
  NMarker? _partnerMarker;
  bool _markersReady = false;
  bool _didInitialCameraFit = false;
  bool _userAdjustedCamera = false;

  static const _fallback = NLatLng(37.5665, 126.9780);
  static const _zoom = 15.0;

  List<NLatLng> get _points {
    final points = <NLatLng>[];
    _addPoint(points, widget.meetingLatitude, widget.meetingLongitude);
    _addPoint(points, widget.myLatitude, widget.myLongitude);
    _addPoint(points, widget.partnerLatitude, widget.partnerLongitude);
    return points;
  }

  void _addPoint(List<NLatLng> points, double? latitude, double? longitude) {
    if (latitude != null && longitude != null) {
      points.add(NLatLng(latitude, longitude));
    }
  }

  Future<void> _fitCamera({bool force = false}) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (_didInitialCameraFit && !force) return;
    final points = _points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: points.first, zoom: _zoom)
          ..setReason(NCameraUpdateReason.developer),
      );
    } else {
      await controller.updateCamera(
        NCameraUpdate.fitBounds(
          NLatLngBounds.from(points),
          padding: const EdgeInsets.all(52),
        )..setReason(NCameraUpdateReason.developer),
      );
    }
    _didInitialCameraFit = true;
    if (force) _userAdjustedCamera = false;
  }

  Future<NMarker?> _upsertMarker({
    required String id,
    required NMarker? current,
    required double? latitude,
    required double? longitude,
    required String caption,
  }) async {
    final controller = _controller;
    if (controller == null || !mounted) return current;
    if (latitude == null || longitude == null) {
      if (current != null) {
        await controller.deleteOverlay(current.info);
      }
      return null;
    }
    final position = NLatLng(latitude, longitude);
    if (current == null) {
      final marker = NMarker(
        id: id,
        position: position,
        caption: NOverlayCaption(text: caption),
      );
      await controller.addOverlay(marker);
      return marker;
    }
    current.setPosition(position);
    current.setCaption(NOverlayCaption(text: caption));
    return current;
  }

  Future<void> _syncMarkers({bool initial = false}) async {
    if (_controller == null || !mounted) return;
    try {
      _meetingMarker = await _upsertMarker(
        id: 'quick_meeting',
        current: _meetingMarker,
        latitude: widget.meetingLatitude,
        longitude: widget.meetingLongitude,
        caption: '만남 위치',
      );
      _myMarker = await _upsertMarker(
        id: 'quick_me',
        current: _myMarker,
        latitude: widget.myLatitude,
        longitude: widget.myLongitude,
        caption: '내 위치',
      );
      _partnerMarker = await _upsertMarker(
        id: 'quick_partner',
        current: _partnerMarker,
        latitude: widget.partnerLatitude,
        longitude: widget.partnerLongitude,
        caption: widget.partnerLabel,
      );
      _markersReady = true;
      if (initial && !_userAdjustedCamera) await _fitCamera();
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant QuickMatchLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_markersReady) return;
    final changed =
        oldWidget.meetingLatitude != widget.meetingLatitude ||
        oldWidget.meetingLongitude != widget.meetingLongitude ||
        oldWidget.myLatitude != widget.myLatitude ||
        oldWidget.myLongitude != widget.myLongitude ||
        oldWidget.partnerLatitude != widget.partnerLatitude ||
        oldWidget.partnerLongitude != widget.partnerLongitude ||
        oldWidget.partnerLabel != widget.partnerLabel;
    if (changed) unawaited(_syncMarkers());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!ttmSupportsEmbeddedNaverMap) {
      return SizedBox(
        height: widget.height,
        child: ColoredBox(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Center(
            child: Text(
              '모바일에서 두 사람의 현재 위치를 확인할 수 있어요.',
              style: TtmTypography.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final initial = _points.isEmpty ? _fallback : _points.first;
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NaverMap(
            forceGesture: true,
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: initial,
                zoom: _zoom,
              ),
              scrollGesturesEnable: true,
              zoomGesturesEnable: true,
              rotationGesturesEnable: true,
              tiltGesturesEnable: false,
              locationButtonEnable: false,
            ),
            onCameraChange: (reason, _) {
              if (reason == NCameraUpdateReason.gesture ||
                  reason == NCameraUpdateReason.control) {
                _userAdjustedCamera = true;
              }
            },
            onMapReady: (controller) async {
              _controller = controller;
              await _syncMarkers(initial: true);
            },
          ),
          Positioned(
            right: TtmSpacing.sm,
            bottom: TtmSpacing.sm,
            child: Material(
              elevation: 2,
              color: colors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(TtmRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(TtmRadius.md),
                onTap: () => unawaited(_fitCamera(force: true)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TtmSpacing.sm,
                    vertical: TtmSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.center_focus_strong, color: colors.primary),
                      const SizedBox(width: 4),
                      const Text('전체 보기'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
