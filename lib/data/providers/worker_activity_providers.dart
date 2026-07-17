import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/worker/matched_worker_location_service.dart';
import '../../core/worker/worker_activity_location_service.dart';
import '../../data/providers/auth_providers.dart';
import '../../features/match/providers/match_providers.dart';

final workerActivityLocationServiceProvider =
    Provider<WorkerActivityLocationService>((ref) {
      final service = WorkerActivityLocationService();
      ref.onDispose(() => service.stop());
      return service;
    });

final matchedWorkerLocationServiceProvider =
    Provider<MatchedWorkerLocationService>((ref) {
      final service = MatchedWorkerLocationService();
      ref.onDispose(() => service.stop());
      return service;
    });

/// 로그인·활동 ON·매칭 진행 상태에 맞춰 백그라운드 위치 추적을 켜고 끈다.
/// 매칭 중(matched)이면 활동 ON보다 우선해 requests.worker_live_geo 를 갱신한다.
class WorkerActivityBootstrap extends ConsumerStatefulWidget {
  const WorkerActivityBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WorkerActivityBootstrap> createState() =>
      _WorkerActivityBootstrapState();
}

class _WorkerActivityBootstrapState
    extends ConsumerState<WorkerActivityBootstrap>
    with WidgetsBindingObserver {
  StreamSubscription<String?>? _matchedSub;
  String? _matchedStreamUid;
  bool _syncRunning = false;
  bool _syncAgain = false;
  bool _initialSyncQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchedSub?.cancel();
    ref.read(workerActivityLocationServiceProvider).stop();
    ref.read(matchedWorkerLocationServiceProvider).stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestSync();
    }
  }

  void _requestSync() {
    if (_syncRunning) {
      _syncAgain = true;
      return;
    }
    unawaited(_drainSync());
  }

  Future<void> _drainSync() async {
    _syncRunning = true;
    try {
      do {
        _syncAgain = false;
        try {
          await _syncTracking();
        } catch (_) {
          // 다음 auth/presence/realtime 이벤트 또는 resume 때 재시도한다.
        }
      } while (_syncAgain && mounted);
    } finally {
      _syncRunning = false;
    }
  }

  void _ensureMatchedStream(String uid) {
    if (_matchedStreamUid == uid && _matchedSub != null) return;
    _matchedSub?.cancel();
    _matchedStreamUid = uid;
    _matchedSub = ref
        .read(matchingRepositoryProvider)
        .watchMyActiveMatchedRequestId(uid)
        .listen((requestId) {
          if (!mounted) return;
          _requestSync();
        });
  }

  Future<void> _syncTracking() async {
    final uid = ref.read(authUserIdProvider);
    if (uid == null) {
      _matchedSub?.cancel();
      _matchedSub = null;
      _matchedStreamUid = null;
      await ref.read(matchedWorkerLocationServiceProvider).stop();
      await ref.read(workerActivityLocationServiceProvider).stop();
      return;
    }

    _ensureMatchedStream(uid);
    final matchedId = await ref
        .read(matchingRepositoryProvider)
        .fetchMyActiveMatchedRequestId(uid);
    await _applyTracking(uid, matchedId);
  }

  Future<void> _applyTracking(String uid, String? matchedRequestId) async {
    final matchedService = ref.read(matchedWorkerLocationServiceProvider);
    final activityService = ref.read(workerActivityLocationServiceProvider);
    final repo = ref.read(matchingRepositoryProvider);

    if (matchedRequestId != null) {
      await activityService.stop();
      await matchedService.start(requestId: matchedRequestId, repo: repo);
      return;
    }

    await matchedService.stop();

    final presence = ref.read(myWorkerPresenceProvider).valueOrNull;
    final status = presence?['status']?.toString();
    final isOnline = status == 'online' || status == 'busy';
    if (!isOnline) {
      await activityService.stop();
      return;
    }

    await activityService.startTracking(workerId: uid, repo: repo);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authUserIdProvider, (_, next) => _requestSync());
    ref.listen(myWorkerPresenceProvider, (_, next) => _requestSync());

    if (!_initialSyncQueued) {
      _initialSyncQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestSync();
      });
    }

    return widget.child;
  }
}

Future<void> _applyWorkerTracking(WidgetRef ref, String uid) async {
  final matchedService = ref.read(matchedWorkerLocationServiceProvider);
  final activityService = ref.read(workerActivityLocationServiceProvider);
  final repo = ref.read(matchingRepositoryProvider);

  final matchedId = await repo.fetchMyActiveMatchedRequestId(uid);
  if (matchedId != null) {
    await activityService.stop();
    await matchedService.start(requestId: matchedId, repo: repo);
    return;
  }

  await matchedService.stop();

  final presence = ref.read(myWorkerPresenceProvider).valueOrNull;
  final status = presence?['status']?.toString();
  final isOnline = status == 'online' || status == 'busy';
  if (!isOnline) {
    await activityService.stop();
    return;
  }

  await activityService.startTracking(workerId: uid, repo: repo);
}

/// 홈 활동 ON/OFF 직후 즉시 추적 시작·중지.
Future<void> syncWorkerActivityTracking(WidgetRef ref) async {
  final uid = ref.read(authUserIdProvider);
  if (uid == null) {
    await ref.read(matchedWorkerLocationServiceProvider).stop();
    await ref.read(workerActivityLocationServiceProvider).stop();
    return;
  }
  await _applyWorkerTracking(ref, uid);
}

/// 매칭 수락·진행 화면 진입 직후 작업자 GPS → requests.worker_live_geo.
Future<void> syncMatchedWorkerTracking(WidgetRef ref) async {
  final uid = ref.read(authUserIdProvider);
  if (uid == null) return;
  await _applyWorkerTracking(ref, uid);
}
