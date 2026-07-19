import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ttm_elevated_card.dart';
import '../../../core/utils/display_nickname.dart';
import '../../../core/utils/ttm_snackbar.dart';
import '../../../core/utils/pedestrian_location.dart';
import '../../../data/models/app_user.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/worker_activity_providers.dart';
import '../../../core/utils/naver_map_support.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../match/models/match_request.dart';
import '../../match/models/request_task_proof.dart';
import '../../match/providers/match_providers.dart';
import '../../reports/report_dialog.dart';
import '../../reports/report_repository.dart';
import '../providers/chat_providers.dart';
import '../../../shared/widgets/ttm_premium_nickname.dart';
import '../../profile/widgets/profile_photo_change.dart';
import '../widgets/match_role_badge.dart';

/// 매칭 직후 심부름 진행: 만남 위치 지도 + DM + 완료 처리 + 후기.
class ActiveMatchScreen extends ConsumerStatefulWidget {
  const ActiveMatchScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ActiveMatchScreen> createState() => _ActiveMatchScreenState();
}

class _TaskVerificationCard extends StatelessWidget {
  const _TaskVerificationCard({
    required this.request,
    required this.proofs,
    required this.isWorker,
    required this.isRequester,
    required this.busy,
    required this.reviewingProofId,
    required this.onSubmit,
    required this.onPreview,
    required this.onReview,
  });

  final MatchRequest request;
  final List<RequestTaskProof> proofs;
  final bool isWorker;
  final bool isRequester;
  final bool busy;
  final String? reviewingProofId;
  final void Function(TaskProofRequirement requirement) onSubmit;
  final ValueChanged<String> onPreview;
  final void Function(RequestTaskProof proof, bool approved) onReview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final requirements = TaskProofPlan.forRequest(request);
    TaskProofRequirement? current;
    for (final requirement in requirements) {
      if (_proofsFor(requirement).length < requirement.requiredCount) {
        current = requirement;
        break;
      }
    }

    return TtmElevatedCard(
      padding: const EdgeInsets.all(TtmSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: colors.primary),
              const SizedBox(width: TtmSpacing.sm),
              Expanded(
                child: Text(
                  '작업 인증',
                  style: TtmTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text('${proofs.length}장', style: TtmTypography.label),
            ],
          ),
          const SizedBox(height: TtmSpacing.sm),
          Text(
            isWorker
                ? '아래 순서대로 앱 카메라로 촬영해 주세요.'
                : '작업자가 제출한 사진과 시각을 확인할 수 있어요.',
            style: TtmTypography.body.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          for (var index = 0; index < requirements.length; index++) ...[
            if (index > 0) const Divider(height: TtmSpacing.lg),
            _buildRequirement(
              context,
              requirements[index],
              isCurrent: identical(current, requirements[index]),
            ),
          ],
        ],
      ),
    );
  }

  List<RequestTaskProof> _proofsFor(TaskProofRequirement requirement) {
    return proofs
        .where(
          (proof) =>
              proof.proofType == requirement.proofType && !proof.isRejected,
        )
        .toList(growable: false);
  }

  List<RequestTaskProof> _allProofsFor(TaskProofRequirement requirement) {
    return proofs
        .where((proof) => proof.proofType == requirement.proofType)
        .toList(growable: false);
  }

  Widget _buildRequirement(
    BuildContext context,
    TaskProofRequirement requirement, {
    required bool isCurrent,
  }) {
    final colors = Theme.of(context).colorScheme;
    final submitted = _proofsFor(requirement);
    final allSubmitted = _allProofsFor(requirement);
    final complete = submitted.length >= requirement.requiredCount;
    final nextAt = _nextAvailableAt(requirement, submitted);
    final remaining = nextAt?.difference(DateTime.now());
    final available = remaining == null || remaining <= Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              complete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 20,
              color: complete ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: TtmSpacing.sm),
            Expanded(
              child: Text(
                requirement.label,
                style: TtmTypography.title.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${submitted.length}/${requirement.requiredCount}',
              style: TtmTypography.label.copyWith(
                color: complete ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xs),
        Text(
          requirement.description,
          style: TtmTypography.body.copyWith(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
        if (allSubmitted.isNotEmpty) ...[
          const SizedBox(height: TtmSpacing.sm),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allSubmitted.length,
              separatorBuilder: (_, _) => const SizedBox(width: TtmSpacing.sm),
              itemBuilder: (context, index) {
                final proof = allSubmitted[index];
                final statusLabel = proof.isRejected
                    ? '반려'
                    : (proof.isPending ? '검토 대기' : '승인');
                final statusColor = proof.isRejected
                    ? colors.error
                    : (proof.isPending
                          ? colors.onSurfaceVariant
                          : colors.primary);
                return SizedBox(
                  width: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onPreview(proof.imageUrl),
                        icon: const Icon(Icons.photo_outlined, size: 16),
                        label: const Text('사진 보기'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.label.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        _timeLabel(proof.createdAt),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.label.copyWith(
                          fontSize: 10,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: TtmSpacing.xs),
          Text(
            '사진 보기 버튼을 눌러 제출 사진을 크게 확인하세요.',
            style: TtmTypography.label.copyWith(
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
          if (allSubmitted.last.reviewedAt != null)
            Text(
              '최근 검토 ${_timeLabel(allSubmitted.last.reviewedAt!)}',
              style: TtmTypography.label.copyWith(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            )
          else
            Text(
              '최근 제출 ${_timeLabel(allSubmitted.last.createdAt)}',
              style: TtmTypography.label.copyWith(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
          for (final proof in allSubmitted.where((item) => item.isRejected))
            Padding(
              padding: const EdgeInsets.only(top: TtmSpacing.xs),
              child: Text(
                '반려 사유: ${proof.reviewReason ?? '사유 없음'}',
                style: TtmTypography.body.copyWith(
                  fontSize: 12,
                  color: colors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (isRequester)
            for (final proof in allSubmitted.where((item) => item.isPending))
              Padding(
                padding: const EdgeInsets.only(top: TtmSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: reviewingProofId == proof.id
                            ? null
                            : () => onReview(proof, false),
                        child: const Text('반려·재촬영'),
                      ),
                    ),
                    const SizedBox(width: TtmSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: reviewingProofId == proof.id
                            ? null
                            : () => onReview(proof, true),
                        child: Text(
                          reviewingProofId == proof.id ? '처리 중' : '승인',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
        if (isWorker && isCurrent && !complete) ...[
          const SizedBox(height: TtmSpacing.sm),
          OutlinedButton.icon(
            onPressed: busy || !available ? null : () => onSubmit(requirement),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_rounded),
            label: Text(
              available
                  ? '${requirement.label} 촬영'
                  : '${_remainingMinutes(remaining)}분 뒤 촬영 가능',
            ),
          ),
        ],
      ],
    );
  }

  DateTime? _nextAvailableAt(
    TaskProofRequirement requirement,
    List<RequestTaskProof> submitted,
  ) {
    if (requirement.proofType == 'waiting_photo' && submitted.isNotEmpty) {
      return submitted.last.createdAt.add(
        Duration(minutes: requirement.intervalMinutes ?? 30),
      );
    }
    if (requirement.proofType == 'care_checkin_photo') {
      final start = _firstProof('care_start_photo');
      return start?.createdAt.add(
        Duration(
          minutes: (requirement.intervalMinutes ?? 30) * (submitted.length + 1),
        ),
      );
    }
    if (requirement.proofType == 'care_end_photo') {
      final start = _firstProof('care_start_photo');
      if (start == null) return null;
      final raw = request.taskOptions['care_duration_minutes'];
      final minutes = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 30;
      return start.createdAt.add(Duration(minutes: minutes));
    }
    return null;
  }

  RequestTaskProof? _firstProof(String proofType) {
    for (final proof in proofs) {
      if (proof.proofType == proofType && !proof.isRejected) return proof;
    }
    return null;
  }

  int _remainingMinutes(Duration remaining) {
    return remaining.inMinutes + (remaining.inSeconds % 60 == 0 ? 0 : 1);
  }

  String _timeLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ActiveMatchScreenState extends ConsumerState<ActiveMatchScreen> {
  bool _completing = false;
  bool _cancelling = false;
  bool _sharingBusy = false;
  bool _proofSubmitting = false;
  String? _reviewingProofId;
  bool _didAttemptReviewPrompt = false;
  bool _mapExpanded = true;
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<Position>? _localWorkerGpsSub;
  String? _locationTrackingRole;
  double? _localWorkerLat;
  double? _localWorkerLng;
  double? _localRequesterLat;
  double? _localRequesterLng;
  Timer? _geoPollTimer;
  MatchRequest? _geoPolledRequest;
  DateTime _lastProofUrlRefreshAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _geoPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_pollRequestGeo());
    });
  }

  Future<void> _pollRequestGeo() async {
    if (!mounted) return;
    if (DateTime.now().difference(_lastProofUrlRefreshAt) >=
        const Duration(minutes: 45)) {
      _lastProofUrlRefreshAt = DateTime.now();
      ref.invalidate(taskProofsProvider(widget.requestId));
    }
    try {
      final req = await ref
          .read(matchingRepositoryProvider)
          .fetchRequest(widget.requestId);
      if (!mounted || req == null) return;
      if (req.isMatched) await _autoCompleteIfDue(req);
      setState(() => _geoPolledRequest = req);
    } catch (_) {}
  }

  Future<void> _autoCompleteIfDue(MatchRequest req) async {
    final requestedAt = req.completionRequestedAt;
    if (requestedAt == null || !req.isMatched) return;
    final dueAt = requestedAt.add(const Duration(minutes: 10));
    if (DateTime.now().toUtc().isBefore(dueAt.toUtc())) return;
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .autoCompleteRequestIfDue(req.id);
      if (!mounted) return;
      if (res['auto_completed'] == true) {
        _snack('완료 요청 후 10분이 지나 자동 완료 처리됐어요.');
        await _refreshRequestState();
      }
    } catch (_) {}
  }

  Future<void> _submitTaskProof(
    MatchRequest req,
    TaskProofRequirement requirement,
  ) async {
    if (_proofSubmitting) return;
    setState(() => _proofSubmitting = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      final storagePath = await ref
          .read(chatAttachmentRepositoryProvider)
          .uploadTaskProofImage(requestId: req.id, file: File(picked.path));
      final result = await ref
          .read(matchingRepositoryProvider)
          .submitTaskProof(
            requestId: req.id,
            proofType: requirement.proofType,
            imageUrl: storagePath,
          );
      if (!mounted) return;
      if (result['ok'] == true) {
        _snack('${requirement.label} 인증을 제출했어요.');
        ref.invalidate(taskProofsProvider(req.id));
      } else if (result['reason'] == 'proof_too_early') {
        _snack('아직 다음 인증 시간이 되지 않았어요.');
      } else if (result['reason'] == 'proof_sequence_required') {
        _snack('앞 단계 인증을 먼저 제출해 주세요.');
      } else if (result['reason'] == 'proof_already_submitted') {
        _snack('이미 제출한 인증이에요.');
      } else {
        _snack('인증 사진을 등록하지 못했어요.');
      }
    } catch (e) {
      if (mounted) _snack('인증 사진을 등록하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _proofSubmitting = false);
    }
  }

  Future<void> _showTaskProofImage(String imageUrl) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text(
                      '사진을 불러오지 못했어요.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: '닫기',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewTaskProof(RequestTaskProof proof, bool approved) async {
    if (_reviewingProofId != null) return;
    String? reason;
    if (!approved) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        builder: (context) => AlertDialog(
          title: const Text('인증 사진을 반려할까요?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('반려하면 작업자는 같은 인증 사진을 다시 촬영해야 합니다.'),
              const SizedBox(height: TtmSpacing.md),
              TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: '재촬영 사유',
                  hintText: '선택 입력',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('반려 및 재촬영 요청'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || !mounted) return;
    }

    setState(() => _reviewingProofId = proof.id);
    try {
      final result = await ref
          .read(matchingRepositoryProvider)
          .reviewTaskProof(
            proofId: proof.id,
            approved: approved,
            reason: reason,
          );
      if (!mounted) return;
      if (result['ok'] == true) {
        _snack(approved ? '인증 사진을 승인했어요.' : '반려하고 재촬영을 요청했어요.');
        ref.invalidate(taskProofsProvider(widget.requestId));
      } else {
        _snack(_taskProofReviewErrorMessage(result['reason']?.toString()));
      }
    } catch (e) {
      if (mounted) _snack('인증 검토 중 오류가 났어요: $e');
    } finally {
      if (mounted) setState(() => _reviewingProofId = null);
    }
  }

  String _taskProofReviewErrorMessage(String? reason) {
    return switch (reason) {
      'proof_not_found' => '인증 사진을 찾지 못했어요. 화면을 새로고침해 주세요.',
      'not_requester' => '요청자만 인증 사진을 검토할 수 있어요.',
      'not_matched' => '진행 중인 ○○에서만 인증 사진을 검토할 수 있어요.',
      'already_reviewed' => '이미 처리된 인증 사진이에요.',
      'review_failed' => '반려 처리 중 서버 오류가 났어요. 잠시 후 다시 시도해 주세요.',
      _ => '인증 사진을 처리하지 못했어요.',
    };
  }

  MatchRequest _mergeGeo(MatchRequest req) {
    final polled = _geoPolledRequest;
    if (polled == null || polled.id != req.id) return req;
    return MatchRequest(
      id: req.id,
      requesterId: req.requesterId,
      title: req.title,
      description: req.description,
      tags: req.tags,
      taskType: req.taskType,
      taskOptions: req.taskOptions,
      taskProofPolicyVersion: req.taskProofPolicyVersion,
      reward: req.reward,
      rewardMin: req.rewardMin,
      rewardMax: req.rewardMax,
      negotiatedReward: req.negotiatedReward,
      negotiatedAt: req.negotiatedAt,
      paymentFlow: polled.paymentFlow,
      generalPaymentStatus: polled.generalPaymentStatus,
      paymentRequiredAt: polled.paymentRequiredAt,
      paymentConfirmedAt: polled.paymentConfirmedAt,
      paymentEnforcementRequired: polled.paymentEnforcementRequired,
      deadline: req.deadline,
      estimatedTaskMinutes: req.estimatedTaskMinutes,
      maxSearchRadiusM: req.maxSearchRadiusM,
      status: polled.status,
      currentStage: req.currentStage,
      nextAdvanceAt: req.nextAdvanceAt,
      stageIntervalSeconds: req.stageIntervalSeconds,
      matchingMode: req.matchingMode,
      createdAt: req.createdAt,
      matchedAt: req.matchedAt,
      completedAt: polled.completedAt ?? req.completedAt,
      failedAt: req.failedAt,
      completionRequestedAt: polled.completionRequestedAt,
      completionRequestedBy: polled.completionRequestedBy,
      completionRejectedAt: polled.completionRejectedAt,
      completionRejectCount: polled.completionRejectCount,
      nextCompletionRequestAt: polled.nextCompletionRequestAt,
      completionAutoCompleteAt: polled.completionAutoCompleteAt,
      workerId: polled.workerId ?? req.workerId,
      notes: req.notes,
      requestLatitude: req.requestLatitude ?? polled.requestLatitude,
      requestLongitude: req.requestLongitude ?? polled.requestLongitude,
      requesterShareLocation: req.requesterShareLocation,
      requesterLiveLatitude:
          polled.requesterLiveLatitude ?? req.requesterLiveLatitude,
      requesterLiveLongitude:
          polled.requesterLiveLongitude ?? req.requesterLiveLongitude,
      workerLiveLatitude: polled.workerLiveLatitude ?? req.workerLiveLatitude,
      workerLiveLongitude:
          polled.workerLiveLongitude ?? req.workerLiveLongitude,
    );
  }

  Future<void> _refreshRequestState() async {
    await _pollRequestGeo();
    ref.invalidate(myActiveMatchedRequestsProvider);
    ref.invalidate(myCompletedRequestsStreamProvider);
    ref.invalidate(myCompletedWorkRequestsProvider);
    ref.invalidate(myCompletedRequestedRequestsProvider);
  }

  @override
  void dispose() {
    _geoPollTimer?.cancel();
    _stopLocationTracking();
    _localWorkerGpsSub?.cancel();
    super.dispose();
  }

  void _stopLocationTracking() {
    _locationSub?.cancel();
    _locationSub = null;
    _locationTrackingRole = null;
  }

  Future<void> _syncLocationTracking(
    MatchRequest req,
    String? uid, {
    bool? requesterSharing,
  }) async {
    if (!req.isMatched || uid == null) {
      _stopLocationTracking();
      return;
    }

    if (uid == req.workerId) {
      await syncMatchedWorkerTracking(ref);
      await _startLocalWorkerGpsPreview();
      return;
    }

    _localWorkerGpsSub?.cancel();
    _localWorkerGpsSub = null;
    _localWorkerLat = null;
    _localWorkerLng = null;

    final requesterShare = requesterSharing ?? req.requesterShareLocation;

    if (uid == req.requesterId && requesterShare) {
      if (_locationTrackingRole == 'requester') return;
      _stopLocationTracking();
      _locationTrackingRole = 'requester';

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      Future<void> publishRequester(
        Position pos, {
        required bool strict,
      }) async {
        if (mounted) {
          setState(() {
            _localRequesterLat = pos.latitude;
            _localRequesterLng = pos.longitude;
          });
        }
        if (strict && !TtmPedestrianLocation.isReliableForPublish(pos)) return;
        try {
          await ref
              .read(matchingRepositoryProvider)
              .updateRequesterLiveLocation(
                requestId: req.id,
                latitude: pos.latitude,
                longitude: pos.longitude,
              );
        } catch (_) {}
      }

      final initial = await TtmPedestrianLocation.obtainPosition();
      if (initial != null) {
        await publishRequester(initial, strict: false);
      }

      var publishedStrict = false;
      _locationSub =
          Geolocator.getPositionStream(
            locationSettings: TtmPedestrianLocation.streamSettings(),
          ).listen((pos) async {
            if (!publishedStrict &&
                TtmPedestrianLocation.isReliableForPublish(pos)) {
              publishedStrict = true;
            }
            await publishRequester(pos, strict: publishedStrict);
          });
      return;
    }

    _localRequesterLat = null;
    _localRequesterLng = null;
    _stopLocationTracking();
  }

  Future<void> _startLocalWorkerGpsPreview() async {
    if (_localWorkerGpsSub != null) return;

    final initial = await TtmPedestrianLocation.obtainPosition();
    if (initial != null && mounted) {
      setState(() {
        _localWorkerLat = initial.latitude;
        _localWorkerLng = initial.longitude;
      });
    }

    _localWorkerGpsSub =
        Geolocator.getPositionStream(
          locationSettings: TtmPedestrianLocation.streamSettings(),
        ).listen((pos) {
          if (!mounted) return;
          if (!TtmPedestrianLocation.isReliableForPreview(pos) &&
              _localWorkerLat != null) {
            return;
          }
          setState(() {
            _localWorkerLat = pos.latitude;
            _localWorkerLng = pos.longitude;
          });
        });
  }

  void _leaveActiveScreen(MatchRequest req) {
    if (req.isMatched && !req.isCompleted) {
      _snack('○○은 계속 진행 중이에요. 홈에서 다시 들어올 수 있어요.');
    }
    context.go(AppRoutes.home);
  }

  Future<void> _onRequesterShareChanged(bool share, MatchRequest req) async {
    if (_sharingBusy) return;
    setState(() => _sharingBusy = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .setRequesterShareLocation(requestId: req.id, share: share);
      if (!mounted) return;
      if (res['ok'] != true) {
        _snack(_shareFailureKo(res['reason']?.toString() ?? 'unknown'));
        return;
      }
      if (share) {
        await _syncLocationTracking(
          req,
          ref.read(authUserIdProvider),
          requesterSharing: true,
        );
        unawaited(_pollRequestGeo());
      } else {
        _stopLocationTracking();
        if (mounted) {
          setState(() {
            _localRequesterLat = null;
            _localRequesterLng = null;
          });
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('위치 공유 설정에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _sharingBusy = false);
    }
  }

  String _shareFailureKo(String reason) {
    switch (reason) {
      case 'not_requester':
        return '요청자만 위치 공유를 바꿀 수 있어요.';
      case 'not_matched':
        return '매칭된 ○○에서만 위치를 공유할 수 있어요.';
      case 'request_not_found':
        return '요청을 찾을 수 없어요.';
      default:
        return '위치 공유 설정에 실패했어요 ($reason).';
    }
  }

  Future<void> _requestCompletion(MatchRequest req) async {
    if (_completing) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('완료를 요청할까요?'),
        content: const Text('요청자가 확인하면 ○○이 종료되고 정산이 진행돼요.\n지금은 아직 진행 중이에요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('완료 요청'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _completing = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .requestCompletion(req.id);
      if (!mounted) return;
      if (res['ok'] == true) {
        await _refreshRequestState();
        if (!mounted) return;
        if (res['auto_completed'] == true) {
          _snack('완료 요청 후 10분이 지나 자동 완료 처리됐어요.');
          return;
        }
        final already = res['already_requested'] == true;
        _snack(
          already
              ? '이미 완료 요청을 보냈어요. 요청자 확인을 기다려 주세요.'
              : '완료 요청을 보냈어요. 요청자 확인을 기다려 주세요.',
        );
      } else {
        _snack(_completionFailureKo(res['reason']?.toString() ?? 'unknown'));
      }
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('완료 요청 중 오류가 났어요: $e');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _confirmCompletion(MatchRequest req) async {
    if (_completing) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작업 완료를 확인할까요?'),
        content: const Text(
          '확인하면 ○○이 종료되고 정산이 진행돼요.\n대화 입력이 잠기고 후기를 남길 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('완료 확인'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _completing = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .confirmCompletion(req.id);
      if (!mounted) return;
      if (res['ok'] == true) {
        await _refreshRequestState();
        if (!mounted) return;
        _snack('○○이 종료됐어요. 정산이 진행돼요.');
      } else {
        _snack(_completionFailureKo(res['reason']?.toString() ?? 'unknown'));
      }
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('완료 확인 중 오류가 났어요: $e');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _rejectCompletion(MatchRequest req) async {
    if (_completing) return;
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('완료 요청을 거부할까요?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '아직 완료되지 않은 이유를 적어 주세요.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('거부'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _completing = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .rejectCompletion(req.id, reason: reasonController.text.trim());
      if (!mounted) return;
      if (res['auto_completed'] == true) {
        await _refreshRequestState();
        if (!mounted) return;
        _snack('완료 요청 후 10분이 지나 자동 완료 처리됐어요.');
      } else if (res['ok'] == true) {
        await _refreshRequestState();
        if (!mounted) return;
        final seconds = res['cooldown_seconds'];
        _snack(
          seconds is int
              ? '완료 요청을 거부했어요. 작업자는 ${_durationShort(Duration(seconds: seconds))} 뒤 다시 요청할 수 있어요.'
              : '완료 요청을 거부했어요.',
        );
      } else {
        _snack(_completionFailureKo(res['reason']?.toString() ?? 'unknown'));
      }
    } catch (e) {
      if (mounted) _snack('완료 거부 중 오류가 났어요: $e');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _cancelMatchedRequest(MatchRequest req) async {
    if (_cancelling || _completing) return;
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('○○을 취소할까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('진행 중 취소는 기록돼요. 애매한 경우에는 패널티 없이 운영 검토용 기록만 남깁니다.'),
            const SizedBox(height: TtmSpacing.md),
            TextField(
              controller: reasonController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '취소 이유',
                hintText: '선택 입력',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .cancelRequest(req.id, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      if (res['ok'] == true) {
        await _refreshRequestState();
        if (!mounted) return;
        _snack(res['message']?.toString() ?? '취소가 완료되었습니다.');
        context.go(AppRoutes.home);
      } else {
        _snack(_cancelFailureKo(res['reason']?.toString() ?? 'unknown'));
      }
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('취소 중 오류가 났어요: $e');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _cancelFailureKo(String reason) {
    switch (reason) {
      case 'request_not_found':
        return '요청을 찾을 수 없어요.';
      case 'not_participant':
      case 'not_owner':
        return '이 ○○을 취소할 권한이 없어요.';
      case 'invalid_state':
        return '이미 종료되었거나 취소할 수 없는 상태예요.';
      default:
        return '취소하지 못했어요 ($reason).';
    }
  }

  String _completionFailureKo(String reason) {
    switch (reason) {
      case 'invalid_state':
        return '이미 종료되었거나 진행 중이 아니에요.';
      case 'not_worker':
        return '작업자만 완료를 요청할 수 있어요.';
      case 'not_requester':
        return '요청자만 완료를 확인할 수 있어요.';
      case 'completion_not_requested':
        return '작업자의 완료 요청이 아직 없어요.';
      case 'waiting_duration_remaining':
        return '설정한 대기 시간이 아직 끝나지 않았어요.';
      case 'waiting_proof_required':
        return '필수 대기 인증 사진을 모두 제출한 뒤 완료를 요청해 주세요.';
      case 'task_duration_remaining':
        return '설정한 작업 시간이 아직 끝나지 않았어요.';
      case 'task_proof_required':
        return '필수 작업 인증 사진을 모두 제출한 뒤 완료를 요청해 주세요.';
      case 'no_worker':
        return '매칭 정보가 없어요.';
      case 'race_or_duplicate':
        return '다른 기기에서 먼저 처리했을 수 있어요.';
      case 'request_not_found':
        return '요청을 찾을 수 없어요.';
      default:
        return '처리하지 못했어요 ($reason).';
    }
  }

  String _durationShort(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (minutes <= 0) return '$seconds초';
    if (seconds == 0) return '$minutes분';
    return '$minutes분 $seconds초';
  }

  Future<void> _maybePromptReview(MatchRequest req) async {
    if (_didAttemptReviewPrompt || !mounted) return;
    _didAttemptReviewPrompt = true;

    final uid = ref.read(authUserIdProvider);
    if (uid == null) return;

    final String? otherId = uid == req.requesterId
        ? req.workerId
        : (uid == req.workerId ? req.requesterId : null);
    if (otherId == null) return;

    final has = await ref
        .read(chatRepositoryProvider)
        .hasMyReviewForRequest(req.id);
    if (!mounted || has) return;

    final counterpart = ref
        .read(
          matchCounterpartProvider((requestId: req.id, counterpartId: otherId)),
        )
        .valueOrNull;
    final counterpartLabel = ttmDisplayNickname(counterpart?.nickname);

    final review = await showDialog<_ReviewSubmitResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _ReviewStarsDialog(counterpartLabel: counterpartLabel),
    );
    if (!mounted || review == null || review.rating < 1) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .submitReview(
            requestId: req.id,
            revieweeId: otherId,
            rating: review.rating,
            comment: review.comment,
          );
      ref.invalidate(myProfileProvider);
      ref.invalidate(myReceivedReviewsProvider);
      ref.invalidate(
        matchCounterpartProvider((requestId: req.id, counterpartId: otherId)),
      );
      ref.invalidate(myCompletedWorkRequestsProvider);
      ref.invalidate(myCompletedRequestedRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('후기를 남겼어요. 고마워요!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) _snack('이미 후기를 남겼어요.');
      } else {
        if (mounted) _snack(e.message);
      }
    } catch (e) {
      if (mounted) _snack('후기 저장에 실패했어요: $e');
    }
  }

  void _snack(String msg) {
    showTtmSnackBar(context, msg);
  }

  void _openChat() {
    context.push('${AppRoutes.requestRoot}/${widget.requestId}/chat');
  }

  Future<void> _reportCounterpart({
    required MatchRequest req,
    required String reportedUserId,
  }) async {
    final result = await showReportDialog(
      context: context,
      title: '사용자 신고',
      categories: ttmUserReportCategories,
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(reportRepositoryProvider)
          .submitUserReport(
            reportedUserId: reportedUserId,
            requestId: req.id,
            category: result.category,
            description: result.description,
          );
      if (mounted) _snack('신고가 접수됐어요.');
    } on PostgrestException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('신고를 접수하지 못했어요: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authUserIdProvider);
    final asyncReq = ref.watch(requestStreamProvider(widget.requestId));

    ref.listen(requestStreamProvider(widget.requestId), (_, next) {
      next.whenData((latest) {
        if (latest == null || !mounted) return;
        _syncLocationTracking(latest, ref.read(authUserIdProvider));
      });
    });

    return asyncReq.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('진행')),
        body: Center(child: Text('불러오지 못했어요.\n$e')),
      ),
      data: (req) {
        if (req == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('진행')),
            body: const Center(child: Text('요청을 찾을 수 없어요.')),
          );
        }

        final merged = _mergeGeo(req);

        if (merged.isOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.go('${AppRoutes.requestRoot}/${widget.requestId}/waiting');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (merged.isFailed || merged.isCancelled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.go(AppRoutes.home);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (merged.isCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybePromptReview(merged);
          });
        }

        final isWorker = uid == merged.workerId;
        final workerLat = isWorker
            ? (_localWorkerLat ?? merged.workerLiveLatitude)
            : merged.workerLiveLatitude;
        final workerLng = isWorker
            ? (_localWorkerLng ?? merged.workerLiveLongitude)
            : merged.workerLiveLongitude;
        final colors = Theme.of(context).colorScheme;
        final isRequester = uid == merged.requesterId;
        final requesterLiveLat = merged.requesterShareLocation
            ? (isRequester
                  ? (_localRequesterLat ?? merged.requesterLiveLatitude)
                  : merged.requesterLiveLatitude)
            : null;
        final requesterLiveLng = merged.requesterShareLocation
            ? (isRequester
                  ? (_localRequesterLng ?? merged.requesterLiveLongitude)
                  : merged.requesterLiveLongitude)
            : null;
        final mapHeight = (MediaQuery.sizeOf(context).height * 0.38).clamp(
          220.0,
          380.0,
        );

        final counterpartId = isRequester
            ? (merged.workerId ?? '')
            : merged.requesterId;
        final counterpartAsync = ref.watch(
          matchCounterpartProvider((
            requestId: widget.requestId,
            counterpartId: counterpartId,
          )),
        );
        final counterpart = counterpartAsync.valueOrNull;
        final unreadCount = ref.watch(
          messagesStreamProvider(widget.requestId).select(
            (asyncValue) => asyncValue.maybeWhen(
              data: (bundle) => bundle.reads.unreadFromCounterpart(
                bundle.messages,
                myUserId: uid ?? '',
              ),
              orElse: () => 0,
            ),
          ),
        );
        final taskProofs =
            ref.watch(taskProofsProvider(widget.requestId)).valueOrNull ??
            const <RequestTaskProof>[];
        final taskProofRequirements = TaskProofPlan.forRequest(merged);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: counterpart == null ? 76 : 104,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  merged.isCompleted ? '종료된 ○○' : '진행 중',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    MatchRoleBadge(isRequester: isRequester, compact: true),
                    const SizedBox(width: TtmSpacing.sm),
                    Expanded(
                      child: Text(
                        isRequester ? '내가 요청한 ○○' : '내가 수행 중',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.label.copyWith(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (counterpart != null) ...[
                  const SizedBox(height: 4),
                  TtmPremiumNickname(
                    nickname: counterpart.nickname,
                    isPremium: counterpart.isPremium,
                    crownSize: 16,
                    style: TtmTypography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: '홈으로',
              onPressed: () => _leaveActiveScreen(merged),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _MapToggleHeader(
                  expanded: _mapExpanded,
                  onTap: () => setState(() => _mapExpanded = !_mapExpanded),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _mapExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: SizedBox(
                    height: mapHeight,
                    child: _MapPanel(
                      requestLat: merged.requestLatitude,
                      requestLng: merged.requestLongitude,
                      workerLat: workerLat,
                      workerLng: workerLng,
                      requesterLiveLat: requesterLiveLat,
                      requesterLiveLng: requesterLiveLng,
                      followWorker:
                          isRequester &&
                          merged.isMatched &&
                          workerLat != null &&
                          workerLng != null,
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
                if (isRequester && merged.isMatched)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: TtmSpacing.lg,
                    ),
                    title: Text(
                      '내 위치 공유',
                      style: TtmTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '켜면 작업자에게 실시간 위치가 보여요.',
                      style: TtmTypography.body.copyWith(fontSize: 13),
                    ),
                    value: merged.requesterShareLocation,
                    onChanged: _sharingBusy
                        ? null
                        : (v) => _onRequesterShareChanged(v, merged),
                  ),
                if (merged.isMatched && taskProofRequirements.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TtmSpacing.lg,
                      TtmSpacing.sm,
                      TtmSpacing.lg,
                      TtmSpacing.xs,
                    ),
                    child: _TaskVerificationCard(
                      request: merged,
                      proofs: taskProofs,
                      isWorker: isWorker,
                      isRequester: isRequester,
                      busy: _proofSubmitting,
                      reviewingProofId: _reviewingProofId,
                      onSubmit: (requirement) =>
                          _submitTaskProof(merged, requirement),
                      onPreview: _showTaskProofImage,
                      onReview: _reviewTaskProof,
                    ),
                  ),
                if (merged.isMatched) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TtmSpacing.lg,
                      TtmSpacing.sm,
                      TtmSpacing.lg,
                      TtmSpacing.xs,
                    ),
                    child: TtmElevatedCard(
                      padding: const EdgeInsets.all(TtmSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (merged.isAwaitingRequesterConfirm)
                            Text(
                              uid == merged.requesterId
                                  ? '작업자가 완료를 요청했어요. 확인해 주세요.'
                                  : '완료 요청을 보냈어요. 요청자 확인을 기다리는 중이에요.',
                              textAlign: TextAlign.center,
                              style: TtmTypography.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          else if (uid == merged.requesterId)
                            Text(
                              '작업자가 완료를 요청하면 확인할 수 있어요.',
                              textAlign: TextAlign.center,
                              style: TtmTypography.body.copyWith(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (uid == merged.workerId) ...[
                            if (merged.isAwaitingRequesterConfirm)
                              const SizedBox(height: TtmSpacing.sm),
                            TTMButton(
                              label: merged.isAwaitingRequesterConfirm
                                  ? '완료 요청됨'
                                  : '완료 요청하기',
                              pill: true,
                              busy: _completing,
                              onPressed:
                                  _completing ||
                                      merged.isAwaitingRequesterConfirm ||
                                      !merged.canRequestCompletionNow
                                  ? null
                                  : () => _requestCompletion(merged),
                            ),
                            if (!merged.canRequestCompletionNow &&
                                merged.nextCompletionRequestAt != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: TtmSpacing.xs,
                                ),
                                child: Text(
                                  '${_durationShort(merged.nextCompletionRequestAt!.difference(DateTime.now()))} 뒤 다시 요청할 수 있어요.',
                                  textAlign: TextAlign.center,
                                  style: TtmTypography.body.copyWith(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                          if (uid == merged.requesterId) ...[
                            if (merged.isAwaitingRequesterConfirm)
                              const SizedBox(height: TtmSpacing.sm),
                            TTMButton(
                              label: '작업 완료 확인',
                              pill: true,
                              busy: _completing,
                              onPressed:
                                  _completing ||
                                      !merged.isAwaitingRequesterConfirm
                                  ? null
                                  : () => _confirmCompletion(merged),
                            ),
                            if (merged.isAwaitingRequesterConfirm) ...[
                              const SizedBox(height: TtmSpacing.sm),
                              TTMButton(
                                label: '완료 거부',
                                variant: TtmButtonVariant.ghost,
                                pill: true,
                                busy: _completing,
                                onPressed: _completing
                                    ? null
                                    : () => _rejectCompletion(merged),
                              ),
                            ],
                          ],
                          const SizedBox(height: TtmSpacing.sm),
                          TTMButton(
                            label: '○○ 취소',
                            variant: TtmButtonVariant.ghost,
                            pill: true,
                            busy: _cancelling,
                            onPressed: _cancelling || _completing
                                ? null
                                : () => _cancelMatchedRequest(merged),
                          ),
                          const SizedBox(height: TtmSpacing.sm),
                          TTMButton(
                            label: '상대 신고',
                            variant: TtmButtonVariant.ghost,
                            pill: true,
                            onPressed: counterpartId.isEmpty
                                ? null
                                : () => _reportCounterpart(
                                    req: merged,
                                    reportedUserId: counterpartId,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (merged.isCompleted)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TtmSpacing.lg,
                      TtmSpacing.sm,
                      TtmSpacing.lg,
                      0,
                    ),
                    child: TtmElevatedCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TtmSpacing.md,
                        vertical: TtmSpacing.sm,
                      ),
                      child: Text(
                        '이 ○○은 종료됐어요. 대화는 읽기만 가능해요.',
                        style: TtmTypography.body.copyWith(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TtmSpacing.lg,
                    TtmSpacing.md,
                    TtmSpacing.lg,
                    TtmSpacing.lg,
                  ),
                  child: _ChatEntryButton(
                    counterpart: counterpart,
                    unreadCount: unreadCount,
                    onTap: _openChat,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapToggleHeader extends StatelessWidget {
  const _MapToggleHeader({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TtmSpacing.lg,
            vertical: TtmSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.map_rounded, size: 20, color: colors.primary),
              const SizedBox(width: TtmSpacing.sm),
              Expanded(
                child: Text(
                  '지도',
                  style: TtmTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Text(
                expanded ? '접기' : '펼치기',
                style: TtmTypography.label.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatEntryButton extends StatelessWidget {
  const _ChatEntryButton({
    required this.counterpart,
    required this.unreadCount,
    required this.onTap,
  });

  final AppUser? counterpart;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = ttmDisplayNickname(counterpart?.nickname);

    return TtmElevatedCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TtmSpacing.md,
            vertical: TtmSpacing.md,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  TtmProfileAvatar(
                    imageUrl: counterpart?.profileImageUrl,
                    size: 44,
                    borderWidth: 1.5,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: TtmTypography.label.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: colors.onError,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: TtmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '메시지',
                      style: TtmTypography.title.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TtmPremiumNickname(
                      nickname: name,
                      isPremium: counterpart?.isPremium ?? false,
                      crownSize: 16,
                      style: TtmTypography.body.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPanel extends StatefulWidget {
  const _MapPanel({
    required this.requestLat,
    required this.requestLng,
    required this.workerLat,
    required this.workerLng,
    required this.requesterLiveLat,
    required this.requesterLiveLng,
    required this.followWorker,
  });

  final double? requestLat;
  final double? requestLng;
  final double? workerLat;
  final double? workerLng;
  final double? requesterLiveLat;
  final double? requesterLiveLng;
  final bool followWorker;

  @override
  State<_MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<_MapPanel> {
  NaverMapController? _controller;
  static const _zoom = 15.0;
  bool _markersReady = false;
  bool _didInitialCameraFit = false;

  /// 사용자가 직접 확대·축소·이동한 뒤에는 카메라를 자동 복구하지 않음.
  bool _userAdjustedCamera = false;

  NMarker? _requestMarker;
  NMarker? _workerMarker;
  NMarker? _requesterMarker;

  NLatLng get _fallback => const NLatLng(37.5665, 126.9780);

  List<NLatLng> get _visiblePoints {
    final points = <NLatLng>[];
    if (widget.requestLat != null && widget.requestLng != null) {
      points.add(NLatLng(widget.requestLat!, widget.requestLng!));
    }
    if (widget.workerLat != null && widget.workerLng != null) {
      points.add(NLatLng(widget.workerLat!, widget.workerLng!));
    }
    if (widget.requesterLiveLat != null && widget.requesterLiveLng != null) {
      points.add(NLatLng(widget.requesterLiveLat!, widget.requesterLiveLng!));
    }
    return points;
  }

  Future<void> _fitInitialCamera() async {
    final ctl = _controller;
    if (ctl == null || !mounted || _didInitialCameraFit) return;

    if (widget.followWorker &&
        widget.workerLat != null &&
        widget.workerLng != null) {
      await ctl.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(widget.workerLat!, widget.workerLng!),
          zoom: _zoom,
        )..setReason(NCameraUpdateReason.developer),
      );
      _didInitialCameraFit = true;
      return;
    }

    final points = _visiblePoints;
    if (points.isEmpty) return;
    if (points.length == 1) {
      await ctl.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: points.first, zoom: _zoom)
          ..setReason(NCameraUpdateReason.developer),
      );
    } else {
      await ctl.updateCamera(
        NCameraUpdate.fitBounds(
          NLatLngBounds.from(points),
          padding: const EdgeInsets.all(48),
        )..setReason(NCameraUpdateReason.developer),
      );
    }
    _didInitialCameraFit = true;
  }

  /// 작업자 위치로만 이동 (현재 줌 유지).
  Future<void> _centerOnWorker() async {
    final ctl = _controller;
    if (ctl == null ||
        !mounted ||
        widget.workerLat == null ||
        widget.workerLng == null) {
      return;
    }
    try {
      await ctl.updateCamera(
        NCameraUpdate.withParams(
          target: NLatLng(widget.workerLat!, widget.workerLng!),
        )..setReason(NCameraUpdateReason.developer),
      );
    } catch (_) {}
  }

  void _onCameraChange(NCameraUpdateReason reason, bool animated) {
    if (reason == NCameraUpdateReason.gesture ||
        reason == NCameraUpdateReason.control) {
      _userAdjustedCamera = true;
    }
  }

  Future<void> _upsertMarker({
    required String id,
    required NMarker? current,
    required void Function(NMarker?) setter,
    required double? lat,
    required double? lng,
    required String caption,
  }) async {
    final ctl = _controller;
    if (ctl == null || !mounted) return;

    if (lat == null || lng == null) {
      if (current != null) {
        try {
          await ctl.deleteOverlay(current.info);
        } catch (_) {}
        setter(null);
      }
      return;
    }

    final pos = NLatLng(lat, lng);
    if (current == null) {
      final marker = NMarker(
        id: id,
        position: pos,
        caption: NOverlayCaption(text: caption),
      );
      await ctl.addOverlay(marker);
      setter(marker);
      return;
    }

    current.setPosition(pos);
  }

  Future<void> _syncMarkers({bool initial = false}) async {
    final ctl = _controller;
    if (ctl == null || !mounted) return;

    try {
      await _upsertMarker(
        id: 'request',
        current: _requestMarker,
        setter: (m) => _requestMarker = m,
        lat: widget.requestLat,
        lng: widget.requestLng,
        caption: '만남 위치',
      );
      await _upsertMarker(
        id: 'worker',
        current: _workerMarker,
        setter: (m) => _workerMarker = m,
        lat: widget.workerLat,
        lng: widget.workerLng,
        caption: '작업자',
      );
      await _upsertMarker(
        id: 'requester_live',
        current: _requesterMarker,
        setter: (m) => _requesterMarker = m,
        lat: widget.requesterLiveLat,
        lng: widget.requesterLiveLng,
        caption: '요청자',
      );

      _markersReady = true;
      if (initial && !_userAdjustedCamera) {
        await _fitInitialCamera();
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _MapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_markersReady) return;
    final coordsChanged =
        oldWidget.requestLat != widget.requestLat ||
        oldWidget.requestLng != widget.requestLng ||
        oldWidget.workerLat != widget.workerLat ||
        oldWidget.workerLng != widget.workerLng ||
        oldWidget.requesterLiveLat != widget.requesterLiveLat ||
        oldWidget.requesterLiveLng != widget.requesterLiveLng ||
        oldWidget.followWorker != widget.followWorker;
    if (coordsChanged) {
      unawaited(_syncMarkers());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasRequest = widget.requestLat != null && widget.requestLng != null;

    if (!ttmSupportsEmbeddedNaverMap) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TtmSpacing.lg),
            child: Text(
              hasRequest
                  ? '이 기기에서는 지도 미리보기만 지원해요.\n만남 위치: ${widget.requestLat!.toStringAsFixed(5)}, ${widget.requestLng!.toStringAsFixed(5)}'
                  : '만남 위치 좌표가 아직 없어요.',
              textAlign: TextAlign.center,
              style: TtmTypography.body.copyWith(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final points = _visiblePoints;
    final NLatLng initial = points.isNotEmpty
        ? points.first
        : hasRequest
        ? NLatLng(widget.requestLat!, widget.requestLng!)
        : _fallback;

    final showWorkerCenter =
        widget.followWorker &&
        widget.workerLat != null &&
        widget.workerLng != null;

    return Stack(
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
          onCameraChange: _onCameraChange,
          onMapReady: (controller) async {
            _controller = controller;
            await _syncMarkers(initial: true);
          },
        ),
        if (showWorkerCenter)
          Positioned(
            right: TtmSpacing.sm,
            bottom: TtmSpacing.sm,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(TtmRadius.md),
              color: scheme.surface.withValues(alpha: 0.94),
              child: InkWell(
                onTap: () => unawaited(_centerOnWorker()),
                borderRadius: BorderRadius.circular(TtmRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TtmSpacing.sm,
                    vertical: TtmSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '작업자 위치',
                        style: TtmTypography.label.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewStarsDialog extends StatefulWidget {
  const _ReviewStarsDialog({required this.counterpartLabel});

  final String counterpartLabel;

  @override
  State<_ReviewStarsDialog> createState() => _ReviewStarsDialogState();
}

class _ReviewSubmitResult {
  const _ReviewSubmitResult({required this.rating, required this.comment});

  final int rating;
  final String comment;
}

class _ReviewStarsDialogState extends State<_ReviewStarsDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('후기 남기기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.counterpartLabel}에게 별점과 후기를 남겨 주세요.',
              style: TtmTypography.body.copyWith(fontSize: 14),
            ),
            const SizedBox(height: TtmSpacing.lg),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final n = i + 1;
                  final on = n <= _rating;
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => setState(() => _rating = n),
                    icon: Icon(
                      on ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 34,
                      color: on
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: TtmSpacing.lg),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '글 후기',
                hintText: '어떤 점이 좋았는지, 다음 거래자에게 도움이 될 내용을 적어 주세요.',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('나중에'),
        ),
        TextButton(
          onPressed: _rating < 1
              ? null
              : () => Navigator.of(context).pop(
                  _ReviewSubmitResult(
                    rating: _rating,
                    comment: _commentController.text.trim(),
                  ),
                ),
          child: const Text('제출'),
        ),
      ],
    );
  }
}
