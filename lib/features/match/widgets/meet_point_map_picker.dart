import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/naver_map_support.dart';
import 'map_gesture_guard.dart';

/// 화면 중앙 핀 기준으로 지도를 움직여 **만남·수행 위치**를 고른다.
///
/// `onPickChanged`는 카메라가 멈출 때마다 호출된다.
class MeetPointMapPicker extends StatefulWidget {
  const MeetPointMapPicker({
    super.key,
    required this.initialCenter,
    required this.onPickChanged,
    this.height = 260,
  });

  final NLatLng initialCenter;
  final void Function(double latitude, double longitude) onPickChanged;
  final double height;

  @override
  State<MeetPointMapPicker> createState() => MeetPointMapPickerState();
}

class MeetPointMapPickerState extends State<MeetPointMapPicker> {
  NaverMapController? _controller;
  double _zoom = 16;

  static const _pinSize = 48.0;
  static const _pinTipOffset = _pinSize / 2;

  @override
  void didUpdateWidget(covariant MeetPointMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final o = oldWidget.initialCenter;
    final n = widget.initialCenter;
    if ((o.latitude - n.latitude).abs() > 1e-7 ||
        (o.longitude - n.longitude).abs() > 1e-7) {
      moveTo(n, zoom: _zoom);
    }
  }

  Future<void> moveTo(NLatLng target, {double? zoom}) async {
    if (zoom != null) _zoom = zoom.clamp(10, 20);
    await _moveCamera(target);
  }

  Future<void> zoomBy(double delta) async {
    final c = _controller;
    if (c == null) return;
    try {
      final cam = await c.getCameraPosition();
      _zoom = (cam.zoom + delta).clamp(10, 20);
      await c.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: cam.target, zoom: _zoom),
      );
      await _publishCenter();
    } catch (_) {}
  }

  Future<void> _moveCamera(NLatLng target) async {
    final c = _controller;
    if (c == null || !mounted) return;
    try {
      await c.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: target, zoom: _zoom),
      );
      await _publishCenter();
    } catch (_) {}
  }

  Future<void> _publishCenter() async {
    final c = _controller;
    if (c == null || !mounted) return;
    try {
      final cam = await c.getCameraPosition();
      widget.onPickChanged(cam.target.latitude, cam.target.longitude);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).brightness == Brightness.dark
        ? TtmColors.primaryDark
        : TtmColors.primary;

    if (!ttmSupportsEmbeddedNaverMap) {
      return SizedBox(
        height: widget.height,
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '모바일(Android/iOS)에서 네이버 지도로 위치를 고를 수 있어요.\n'
                '이 기기에서는 아래 「내 위치」를 사용해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MapGestureGuard(
              child: NaverMap(
                forceGesture: true,
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: widget.initialCenter,
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
                  await _moveCamera(widget.initialCenter);
                },
                onCameraIdle: _publishCenter,
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -_pinTipOffset),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: _pinSize,
                    color: primary,
                    shadows: const [
                      Shadow(
                        color: Color(0x59000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ZoomButton(icon: Icons.add_rounded, onTap: () => zoomBy(1)),
                  const SizedBox(height: 6),
                  _ZoomButton(
                    icon: Icons.remove_rounded,
                    onTap: () => zoomBy(-1),
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

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: TtmColors.primary),
        ),
      ),
    );
  }
}
