import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../core/utils/relative_time_ko.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../match/models/worker_notification.dart';

/// 홈·태스크 탭용 밀도 높은 심부름 카드 (Tier3 Feed).
class TtmDenseTaskCard extends StatelessWidget {
  const TtmDenseTaskCard({
    super.key,
    required this.notification,
    required this.onAccept,
    required this.busy,

    /// 홈 FAB(+ 버튼)과 수락 버튼 겹침 방지용 우측 여백.
    this.trailingClearance = 0,
    this.featured = false,
    this.actionLabel,
  });

  final WorkerNotification notification;
  final VoidCallback onAccept;
  final bool busy;
  final double trailingClearance;
  final bool featured;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final req = notification.request;
    final title = req?.description.isNotEmpty == true
        ? req!.description
        : '주변 심부름';
    final reward = req?.rewardLabel(suffix: '') ?? '?';
    final eta = notification.etaMinutes == null
        ? '—'
        : '${notification.etaMinutes}분';
    final dist = notification.distanceKm == null
        ? '—'
        : (notification.distanceKm! >= 1
              ? '${notification.distanceKm!.toStringAsFixed(1)}km'
              : '${(notification.distanceKm! * 1000).round()}m');

    final taskMin = req?.estimatedTaskMinutes;
    final taskTypeLabel = req?.taskPolicy.type.label;
    final relative = formatRelativeTimeKo(notification.createdAt);
    final tier = featured ? TtmCardTier.mission : TtmCardTier.feed;
    final accent = featured ? semantic.missionAccent : semantic.brandTeal;

    return TtmTierCard(
      tier: tier,
      padding: const EdgeInsets.all(TtmSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TtmTypography.title.copyWith(
                    fontSize: featured ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: TtmSpacing.sm),
              Text(
                relative,
                style: TtmTypography.label.copyWith(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (taskTypeLabel != null) ...[
            const SizedBox(height: TtmSpacing.sm),
            Wrap(
              spacing: TtmSpacing.xs,
              runSpacing: TtmSpacing.xs,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(TtmRadius.pill),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    taskTypeLabel,
                    style: TtmTypography.label.copyWith(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: TtmSpacing.sm),
          Row(
            children: [
              Text(
                '₩$reward',
                style: TtmTypography.moneyDisplay.copyWith(
                  fontSize: featured ? 22 : 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: TtmSpacing.md),
              Expanded(
                child: Text(
                  [
                    dist,
                    '도착 $eta',
                    if (taskMin != null) '$taskMin분',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TtmTypography.body.copyWith(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.md),
          Padding(
            padding: EdgeInsets.only(right: trailingClearance),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                onPressed: busy ? null : onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: semantic.missionAccent,
                  foregroundColor: semantic.onMissionAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TtmRadius.pill),
                  ),
                  textStyle: TtmTypography.button.copyWith(fontSize: 14),
                ),
                child: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: semantic.onMissionAccent,
                        ),
                      )
                    : Text(actionLabel ?? '수락'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
