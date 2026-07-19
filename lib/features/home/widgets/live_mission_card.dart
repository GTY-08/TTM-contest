import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../core/utils/relative_time_ko.dart';
import '../../../shared/widgets/ttm_live_dot.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../match/models/match_request.dart';
import '../../match/models/worker_notification.dart';

/// Tier1 — 진행 중 LIVE 또는 피드 Featured.
class LiveMissionCard extends StatefulWidget {
  const LiveMissionCard.active({
    super.key,
    required this.request,
    required this.onOpen,
    required this.currentUserId,
  }) : notification = null,
       onAccept = null,
       busy = false;

  const LiveMissionCard.featured({
    super.key,
    required this.notification,
    required this.onAccept,
    required this.busy,
  }) : request = null,
       currentUserId = null,
       onOpen = null;

  final MatchRequest? request;
  final WorkerNotification? notification;
  final String? currentUserId;
  final VoidCallback? onOpen;
  final VoidCallback? onAccept;
  final bool busy;

  @override
  State<LiveMissionCard> createState() => _LiveMissionCardState();
}

class _LiveMissionCardState extends State<LiveMissionCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant LiveMissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final shouldTick = widget.request != null;
    if (!shouldTick) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final isActive = widget.request != null;

    final String title;
    final num reward;
    final String dist;
    final String eta;
    final String? taskMin;
    final String? relative;
    final String? roleLabel;
    final String? elapsedLabel;
    final Color? borderColor;

    if (isActive) {
      final r = widget.request!;
      title = r.description.isEmpty ? '진행 중인 ○○' : r.description;
      reward = r.reward;
      dist = '—';
      eta = r.estimatedTaskMinutes > 0 ? '약 ${r.estimatedTaskMinutes}분' : '—';
      taskMin = null;
      relative = null;
      final isRequester = widget.currentUserId == r.requesterId;
      roleLabel = isRequester ? '요청자' : '작업자';
      elapsedLabel = _formatElapsed(
        DateTime.now().difference((r.matchedAt ?? r.createdAt).toLocal()),
      );
      borderColor = isRequester ? const Color(0xFF0278F5) : null;
    } else {
      final n = widget.notification!;
      final req = n.request;
      title = req?.description.isNotEmpty == true ? req!.description : '주변 ○○';
      reward = req?.reward ?? 0;
      dist = n.distanceKm == null
          ? '—'
          : (n.distanceKm! >= 1
                ? '${n.distanceKm!.toStringAsFixed(1)}km'
                : '${(n.distanceKm! * 1000).round()}m');
      eta = n.etaMinutes == null ? '—' : '${n.etaMinutes}분';
      taskMin = req?.estimatedTaskMinutes != null
          ? '${req!.estimatedTaskMinutes}분'
          : null;
      relative = formatRelativeTimeKo(n.createdAt);
      roleLabel = null;
      elapsedLabel = null;
      borderColor = null;
    }

    final rewardFmt = NumberFormat.decimalPattern('ko').format(reward);
    final meta = isActive
        ? eta
        : [dist, '도착 $eta', ?taskMin, ?relative].join(' · ');

    return TtmTierCard(
      tier: TtmCardTier.mission,
      borderColorOverride: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const TtmLiveDot(size: 8),
              const SizedBox(width: TtmSpacing.sm),
              Text(
                isActive ? 'LIVE' : '추천',
                style: TtmTypography.label.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: semantic.missionAccent,
                ),
              ),
              if (roleLabel != null) ...[
                const SizedBox(width: TtmSpacing.sm),
                _RolePill(
                  label: roleLabel,
                  color: borderColor ?? semantic.missionAccent,
                ),
              ],
              const Spacer(),
              Text(
                '₩$rewardFmt',
                style: TtmTypography.moneyDisplay.copyWith(
                  fontSize: 30,
                  color: semantic.missionAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TtmTypography.title.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: TtmSpacing.sm),
          Text(
            isActive && elapsedLabel != null
                ? '$meta · 진행 $elapsedLabel'
                : meta,
            style: TtmTypography.body.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TtmSpacing.lg),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.busy
                  ? null
                  : (isActive ? widget.onOpen : widget.onAccept),
              style: FilledButton.styleFrom(
                backgroundColor: semantic.missionAccent,
                foregroundColor: semantic.onMissionAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TtmRadius.pill),
                ),
                textStyle: TtmTypography.button.copyWith(fontSize: 15),
              ),
              child: widget.busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: semantic.onMissionAccent,
                      ),
                    )
                  : Text(isActive ? '진행 화면' : '수락'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatElapsed(Duration value) {
  final seconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TtmTypography.label.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
