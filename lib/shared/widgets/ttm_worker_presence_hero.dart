import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:postgrest/postgrest.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/ttm_card_tier.dart';
import '../../core/theme/ttm_semantic_colors.dart';
import '../../shared/widgets/ttm_live_dot.dart';
import '../../shared/widgets/ttm_tier_card.dart';
import '../../data/providers/activity_widget_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/worker_activity_providers.dart';
import '../../features/auth/auth_error_message.dart';
import '../../features/match/models/request_tag.dart';
import '../../features/match/providers/match_providers.dart';

/// 홈 Tier2 — 활동 ON (라임·그라데이션 절제).
class TtmWorkerPresenceHero extends ConsumerStatefulWidget {
  const TtmWorkerPresenceHero({super.key});

  @override
  ConsumerState<TtmWorkerPresenceHero> createState() =>
      _TtmWorkerPresenceHeroState();
}

class _TtmWorkerPresenceHeroState extends ConsumerState<TtmWorkerPresenceHero> {
  bool _busy = false;
  Timer? _autoOffTimer;
  DateTime? _onlineUntil;
  String? _scheduledUntilKey;

  @override
  void initState() {
    super.initState();
    // 활동 위젯 "직접 시간 설정" 딥링크로 진입한 경우 시트를 바로 연다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _consumeSheetRequest(ref.read(activityDurationSheetRequestProvider));
    });
  }

  void _consumeSheetRequest(bool requested) {
    if (!requested) return;
    ref.read(activityDurationSheetRequestProvider.notifier).state = false;
    if (!_busy) _setOnline();
  }

  @override
  void dispose() {
    _autoOffTimer?.cancel();
    super.dispose();
  }

  Future<Position> _obtainPosition() async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final age = DateTime.now().difference(last.timestamp);
      if (age <= const Duration(minutes: 10)) {
        return last;
      }
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

  String? _presenceErrorMessage(Object e) {
    if (e is TimeoutException) {
      return '위치 신호를 받는 데 시간이 걸렸어요. GPS를 켠 뒤 잠시 후 다시 시도해 주세요.';
    }
    if (e is LocationServiceDisabledException) {
      return '위치 서비스를 켜야 알림을 받을 수 있어요.';
    }
    if (e is PermissionDeniedException) {
      return '위치 권한을 허용해 주세요.';
    }
    if (e is PostgrestException) {
      return describeAuthError(e);
    }
    return null;
  }

  Future<Duration?> _pickOnlineDuration() async {
    var selected = const Duration(hours: 1);
    return showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
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
                  Text(
                    '얼마 동안 활동할까요?',
                    style: TtmTypography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                  Text(
                    '시간과 분을 스크롤로 고르세요. 선택한 시간이 지나면 자동으로 활동 OFF로 전환돼요.',
                    style: TtmTypography.body.copyWith(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.lg),
                  Wrap(
                    spacing: TtmSpacing.sm,
                    runSpacing: TtmSpacing.sm,
                    children: [
                      _DurationChip(
                        label: '30분',
                        duration: const Duration(minutes: 30),
                        selected: selected == const Duration(minutes: 30),
                        onSelect: (duration) {
                          setSheetState(() => selected = duration);
                        },
                      ),
                      _DurationChip(
                        label: '1시간',
                        duration: const Duration(hours: 1),
                        selected: selected == const Duration(hours: 1),
                        onSelect: (duration) {
                          setSheetState(() => selected = duration);
                        },
                      ),
                      _DurationChip(
                        label: '2시간',
                        duration: const Duration(hours: 2),
                        selected: selected == const Duration(hours: 2),
                        onSelect: (duration) {
                          setSheetState(() => selected = duration);
                        },
                      ),
                      _DurationChip(
                        label: '4시간',
                        duration: const Duration(hours: 4),
                        selected: selected == const Duration(hours: 4),
                        onSelect: (duration) {
                          setSheetState(() => selected = duration);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: TtmSpacing.lg),
                  Container(
                    height: 168,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hm,
                      minuteInterval: 5,
                      initialTimerDuration: selected,
                      onTimerDurationChanged: (duration) {
                        final normalized = duration.inMinutes < 5
                            ? const Duration(minutes: 5)
                            : duration;
                        setSheetState(() => selected = normalized);
                      },
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.lg),
                  Text(
                    '선택 시간: ${_durationLabel(selected)}',
                    textAlign: TextAlign.center,
                    style: TtmTypography.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.md),
                  FilledButton(
                    onPressed: selected.inMinutes < 5
                        ? null
                        : () => Navigator.of(context).pop(selected),
                    child: const Text('활동 시작'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _durationLabel(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '$hours시간 $minutes분';
    }
    if (hours > 0) {
      return '$hours시간';
    }
    return '$minutes분';
  }

  void _startAutoOffTimerUntil(DateTime until) {
    final normalized = until.toUtc();
    final key = normalized.toIso8601String();
    if (_scheduledUntilKey == key && _autoOffTimer != null) return;
    _autoOffTimer?.cancel();
    _scheduledUntilKey = key;
    _onlineUntil = normalized;
    _autoOffTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final until = _onlineUntil;
      if (until == null) return;
      if (DateTime.now().isBefore(until)) {
        if (mounted) setState(() {});
        return;
      }
      _autoOffTimer?.cancel();
      _autoOffTimer = null;
      _onlineUntil = null;
      _scheduledUntilKey = null;
      if (mounted) {
        unawaited(_setOffline(showSnack: true));
      }
    });
  }

  void _syncAutoOffFromPresence(Map<String, dynamic>? presence) {
    final status = presence?['status']?.toString();
    final active = status == 'online' || status == 'busy';
    final rawUntil = presence?['online_until']?.toString();
    final until = rawUntil == null ? null : DateTime.tryParse(rawUntil);
    if (!active || until == null) {
      if (!active) {
        _autoOffTimer?.cancel();
        _autoOffTimer = null;
        _onlineUntil = null;
        _scheduledUntilKey = null;
      }
      return;
    }
    _startAutoOffTimerUntil(until);
  }

  Future<void> _setOnline() async {
    if (_busy) return;
    final duration = await _pickOnlineDuration();
    if (duration == null || !mounted) return;
    setState(() => _busy = true);
    String? failure;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        failure = '위치 서비스를 켜야 알림을 받을 수 있어요.';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.deniedForever) {
          failure = '위치 권한이 꺼져 있어요. 설정에서 틈틈 앱의 위치 권한을 허용해 주세요.';
        } else if (perm == LocationPermission.denied) {
          failure = '위치 권한을 허용해 주세요.';
        } else {
          final pos = await _obtainPosition();
          final uid = ref.read(authUserIdProvider);
          if (uid == null) {
            failure = '로그인이 필요해요.';
          } else {
            final repo = ref.read(matchingRepositoryProvider);
            final onlineUntil = DateTime.now().add(duration);
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
            _startAutoOffTimerUntil(onlineUntil);
          }
        }
      }
    } catch (e) {
      failure = _presenceErrorMessage(e) ?? '활동 시작에 실패했어요. 다시 시도해 주세요.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (failure != null && mounted) {
      _snack(failure);
    }
  }

  Future<void> _setOffline({bool showSnack = false}) async {
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
      _autoOffTimer?.cancel();
      _autoOffTimer = null;
      _onlineUntil = null;
      _scheduledUntilKey = null;
      if (showSnack && mounted) {
        _snack('설정한 활동 시간이 지나 자동으로 OFF로 전환됐어요.');
      }
    } catch (e) {
      if (mounted) {
        _snack(_presenceErrorMessage(e) ?? '상태를 바꾸지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _heroSubtitle(bool isOnline, int? nearbyCount) {
    if (!isOnline) return '켜면 주변 요청 알림을 받아요';
    final remaining = _remainingText();
    if (remaining != null) return '자동 OFF까지 $remaining · ${nearbyCount ?? 0}건';
    if (nearbyCount == null) return '주변 요청을 불러오는 중…';
    if (nearbyCount == 0) return '지금은 주변에 열린 요청이 없어요';
    return '주변 $nearbyCount건';
  }

  String? _remainingText() {
    final until = _onlineUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative) return '00:00';
    final hours = left.inHours;
    final minutes = left.inMinutes.remainder(60);
    final seconds = left.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours시간 ${minutes.toString().padLeft(2, '0')}분';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(activityDurationSheetRequestProvider, (_, next) {
      _consumeSheetRequest(next);
    });
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final presence = ref.watch(myWorkerPresenceProvider);
    final feed = ref.watch(myPendingNotificationsProvider);
    final presenceRow = presence.valueOrNull;
    final status = presenceRow?['status']?.toString();
    final isOnline = status == 'online' || status == 'busy';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAutoOffFromPresence(presenceRow);
    });
    final nearbyCount = feed.valueOrNull?.length;
    final statusLabelColor = isOnline
        ? semantic.missionAccent
        : colors.onSurfaceVariant;

    return TtmTierCard(
      tier: TtmCardTier.status,
      padding: const EdgeInsets.all(TtmSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isOnline) ...[
                          TtmLiveDot(size: 8, color: semantic.missionAccent),
                          const SizedBox(width: TtmSpacing.sm),
                          Text(
                            '활동 중',
                            style: TtmTypography.eyebrow.copyWith(
                              color: statusLabelColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ] else
                          Text(
                            '활동 OFF',
                            style: TtmTypography.eyebrow.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    if (!isOnline) ...[
                      const SizedBox(height: TtmSpacing.sm),
                      Text(
                        '알림 받기를 켜 주세요',
                        style: TtmTypography.title.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.35,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                    if (isOnline && nearbyCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _heroSubtitle(isOnline, nearbyCount),
                        style: TtmTypography.body.copyWith(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: isOnline,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    if (_busy) return;
                    if (v) {
                      _setOnline();
                    } else {
                      _setOffline();
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.duration,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final Duration duration;
  final bool selected;
  final ValueChanged<Duration> onSelect;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(duration),
    );
  }
}
