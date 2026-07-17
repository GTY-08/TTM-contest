import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_elevated_card.dart';
import '../models/worker_notification.dart';

/// 작업자 매칭 알림 카드 — 보상·거리·ETA + 수락 CTA.
class WorkerNotificationCard extends StatelessWidget {
  const WorkerNotificationCard({
    super.key,
    required this.notification,
    required this.onAccept,
    required this.busy,
    this.urgent = false,
  });

  final WorkerNotification notification;
  final Future<void> Function() onAccept;
  final bool busy;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TtmColors.primaryDark : TtmColors.primary;
    final req = notification.request;

    final reward = req != null
        ? NumberFormat.decimalPattern('ko').format(req.reward)
        : '?';
    final etaText = notification.etaMinutes == null
        ? '-'
        : '${notification.etaMinutes}분';
    final distanceText = notification.distanceKm == null
        ? '-'
        : (notification.distanceKm! >= 1
              ? '${notification.distanceKm!.toStringAsFixed(1)}km'
              : '${(notification.distanceKm! * 1000).round()}m');

    return TtmElevatedCard(
      urgent: urgent,
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        TtmSpacing.lg,
        TtmSpacing.lg,
        TtmSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatBlock(
                label: '보상',
                value: '₩$reward',
                emphasized: true,
                accent: accent,
              ),
              const SizedBox(width: TtmSpacing.lg),
              _StatBlock(
                label: '거리',
                value: distanceText,
                metricColor: TtmColors.infoSlate,
              ),
              const SizedBox(width: TtmSpacing.lg),
              _StatBlock(
                label: '도착',
                value: etaText,
                metricColor: TtmColors.infoSlate,
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.lg),
          if (req != null) ...[
            Text(
              req.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TtmTypography.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: TtmSpacing.md),
            Wrap(
              spacing: TtmSpacing.sm,
              runSpacing: TtmSpacing.xs,
              children: [
                for (final t in req.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TtmSpacing.md,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? TtmColors.infoBg.withValues(alpha: 0.35)
                          : TtmColors.infoBg,
                      borderRadius: BorderRadius.circular(TtmRadius.pill),
                    ),
                    child: Text(
                      t,
                      style: TtmTypography.label.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? colors.onSurfaceVariant
                            : TtmColors.infoSlate,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: TtmSpacing.lg),
          ],
          TTMButton(
            label: '수락하기',
            busy: busy,
            pill: true,
            onPressed: busy ? null : () => onAccept(),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.accent,
    this.metricColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? accent;
  final Color? metricColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valueColor = emphasized
        ? (accent ?? colors.primary)
        : (metricColor ?? colors.onSurface);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TtmTypography.label.copyWith(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style:
                (emphasized
                        ? TtmTypography.moneyDisplay.copyWith(fontSize: 20)
                        : TtmTypography.metric)
                    .copyWith(
                      color: valueColor,
                      letterSpacing: emphasized ? -0.4 : 0,
                    ),
          ),
        ],
      ),
    );
  }
}
