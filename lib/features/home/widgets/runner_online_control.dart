import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/worker_activity_providers.dart';
import '../../../features/auth/auth_error_message.dart';
import '../../../features/match/models/request_tag.dart';
import '../../../features/match/providers/match_providers.dart';
import '../../../shared/widgets/ttm_live_dot.dart';

/// 주변 요청 수신 ON/OFF — 홈 상단 컴팩트.
class RunnerOnlineControl extends ConsumerStatefulWidget {
  const RunnerOnlineControl({super.key});

  @override
  ConsumerState<RunnerOnlineControl> createState() =>
      _RunnerOnlineControlState();
}

class _RunnerOnlineControlState extends ConsumerState<RunnerOnlineControl> {
  bool _busy = false;

  Future<Position> _obtainPosition() async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final age = DateTime.now().difference(last.timestamp);
      if (age <= const Duration(minutes: 10)) return last;
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 18),
      );
    } on TimeoutException {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 25),
      );
    }
  }

  String? _err(Object e) {
    if (e is TimeoutException) {
      return 'GPS 신호가 약해요. 잠시 후 다시 시도해 주세요.';
    }
    if (e is LocationServiceDisabledException) {
      return '위치 서비스를 켜 주세요.';
    }
    if (e is PermissionDeniedException) return '위치 권한을 허용해 주세요.';
    if (e is PostgrestException) return describeAuthError(e);
    return null;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _setOnline() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? fail;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        fail = '위치 서비스를 켜 주세요.';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.deniedForever) {
          fail = '설정에서 위치 권한을 허용해 주세요.';
        } else if (perm == LocationPermission.denied) {
          fail = '위치 권한을 허용해 주세요.';
        } else {
          final pos = await _obtainPosition();
          final uid = ref.read(authUserIdProvider);
          if (uid == null) {
            fail = '로그인이 필요해요.';
          } else {
            final repo = ref.read(matchingRepositoryProvider);
            final onlineUntil = DateTime.now().add(const Duration(hours: 1));
            await repo.upsertMyPresence(
              workerId: uid,
              status: 'online',
              latitude: pos.latitude,
              longitude: pos.longitude,
              preferredTags: TtmRequestTags.all,
              maxDistanceKm: 5,
              onlineUntil: onlineUntil,
            );
            try {
              await repo.syncMyWorkerNotifications();
              await repo.flushPushDelivery();
            } catch (_) {}
            ref.invalidate(myWorkerPresenceProvider);
            ref.invalidate(myPendingNotificationsProvider);
            await syncWorkerActivityTracking(ref);
          }
        }
      }
    } catch (e) {
      fail = _err(e) ?? '활동 시작에 실패했어요.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (fail != null && mounted) _snack(fail);
  }

  Future<void> _setOffline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final uid = ref.read(authUserIdProvider);
      if (uid != null) {
        await ref
            .read(matchingRepositoryProvider)
            .upsertMyPresence(
              workerId: uid,
              status: 'offline',
              clearOnlineUntil: true,
            );
        await syncWorkerActivityTracking(ref);
        ref.invalidate(myWorkerPresenceProvider);
      }
    } catch (e) {
      if (mounted) _snack(_err(e) ?? '상태 변경 실패');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presence = ref.watch(myWorkerPresenceProvider);
    final status = presence.valueOrNull?['status']?.toString();
    final isOnline = status == 'online' || status == 'busy';

    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOnline) const TtmLiveDot(size: 6),
        if (isOnline) const SizedBox(width: TtmSpacing.sm),
        Text(
          isOnline ? '수신 ON' : '수신 OFF',
          style: TtmTypography.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isOnline ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: TtmSpacing.sm),
        if (_busy)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isOnline,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => v ? _setOnline() : _setOffline(),
            ),
          ),
      ],
    );
  }
}
