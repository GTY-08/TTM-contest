import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/display_nickname.dart';
import '../../../core/utils/naver_map_support.dart';
import '../models/raid_models.dart';

class RaidLiveMap extends StatefulWidget {
  const RaidLiveMap({
    super.key,
    required this.meetingLatitude,
    required this.meetingLongitude,
    required this.meetingLabel,
    required this.locations,
    required this.participants,
    required this.myUserId,
    this.height = 280,
  });

  final double meetingLatitude;
  final double meetingLongitude;
  final String meetingLabel;
  final List<RaidLiveLocation> locations;
  final List<RaidParticipant> participants;
  final String? myUserId;
  final double height;

  @override
  State<RaidLiveMap> createState() => _RaidLiveMapState();
}

class _RaidLiveMapState extends State<RaidLiveMap> {
  NaverMapController? _controller;
  NMarker? _meetingMarker;
  final _participantMarkers = <String, NMarker>{};
  bool _didInitialCameraFit = false;
  bool _userAdjustedCamera = false;

  List<NLatLng> get _points => [
    NLatLng(widget.meetingLatitude, widget.meetingLongitude),
    for (final location in widget.locations)
      NLatLng(location.latitude, location.longitude),
  ];

  Future<void> _fitCamera({bool force = false}) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (_didInitialCameraFit && !force) return;
    final points = _points;
    if (points.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: points.first, zoom: 16)
          ..setReason(NCameraUpdateReason.developer),
      );
    } else {
      await controller.updateCamera(
        NCameraUpdate.fitBounds(
          NLatLngBounds.from(points),
          padding: const EdgeInsets.all(54),
        )..setReason(NCameraUpdateReason.developer),
      );
    }
    _didInitialCameraFit = true;
    if (force) _userAdjustedCamera = false;
  }

  Future<void> _syncMarkers({bool initial = false}) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      final meetingPosition = NLatLng(
        widget.meetingLatitude,
        widget.meetingLongitude,
      );
      if (_meetingMarker == null) {
        _meetingMarker = NMarker(
          id: 'raid_meeting',
          position: meetingPosition,
          caption: NOverlayCaption(text: '집합 · ${widget.meetingLabel}'),
        );
        await controller.addOverlay(_meetingMarker!);
      } else {
        _meetingMarker!
          ..setPosition(meetingPosition)
          ..setCaption(NOverlayCaption(text: '집합 · ${widget.meetingLabel}'));
      }

      final participants = {
        for (final participant in widget.participants)
          participant.userId: participant,
      };
      final activeIds = widget.locations
          .map((location) => location.userId)
          .toSet();
      final removedIds = _participantMarkers.keys
          .where((id) => !activeIds.contains(id))
          .toList(growable: false);
      for (final id in removedIds) {
        final marker = _participantMarkers.remove(id);
        if (marker != null) await controller.deleteOverlay(marker.info);
      }

      for (final location in widget.locations) {
        final participant = participants[location.userId];
        final name = location.userId == widget.myUserId
            ? '내 위치'
            : ttmDisplayNickname(participant?.nickname);
        final caption =
            participant?.isOrganizer == true &&
                location.userId != widget.myUserId
            ? '$name · 운영자'
            : name;
        final position = NLatLng(location.latitude, location.longitude);
        final current = _participantMarkers[location.userId];
        if (current == null) {
          final marker = NMarker(
            id: 'raid_member_${location.userId}',
            position: position,
            caption: NOverlayCaption(text: caption),
          );
          _participantMarkers[location.userId] = marker;
          await controller.addOverlay(marker);
        } else {
          current
            ..setPosition(position)
            ..setCaption(NOverlayCaption(text: caption));
        }
      }
      if (initial && !_userAdjustedCamera) await _fitCamera();
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant RaidLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.meetingLatitude != widget.meetingLatitude ||
        oldWidget.meetingLongitude != widget.meetingLongitude ||
        oldWidget.meetingLabel != widget.meetingLabel ||
        oldWidget.locations.length != widget.locations.length ||
        !_sameLocations(oldWidget.locations, widget.locations);
    if (changed) unawaited(_syncMarkers());
  }

  bool _sameLocations(
    List<RaidLiveLocation> previous,
    List<RaidLiveLocation> current,
  ) {
    if (previous.length != current.length) return false;
    for (var index = 0; index < previous.length; index++) {
      final before = previous[index];
      final after = current[index];
      if (before.userId != after.userId ||
          before.latitude != after.latitude ||
          before.longitude != after.longitude ||
          before.capturedAt != after.capturedAt) {
        return false;
      }
    }
    return true;
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
              '모바일에서 집합 장소와 참가자 위치를 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TtmTypography.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(TtmRadius.lg),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NaverMap(
              forceGesture: true,
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(
                    widget.meetingLatitude,
                    widget.meetingLongitude,
                  ),
                  zoom: 16,
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
      ),
    );
  }
}
