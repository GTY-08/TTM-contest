import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time_ko.dart';
import '../../match/models/request_task_type.dart';
import '../../match/models/worker_notification.dart';

class GeneralRequestPostCard extends StatelessWidget {
  const GeneralRequestPostCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.onApply,
    this.applied = false,
    this.busy = false,
  });

  final WorkerNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onApply;
  final bool applied;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final request = notification.request;
    if (request == null) return const SizedBox.shrink();
    final thumbnail = notification.thumbnailUrl ?? request.thumbnailUrl;
    final taskMinutes = request.estimatedTaskMinutes;
    final commentCount = notification.commentCount > 0
        ? notification.commentCount
        : request.commentCount;
    final applicationCount = notification.applicationCount > 0
        ? notification.applicationCount
        : request.applicationCount;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(TtmRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TtmRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(TtmSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(TtmRadius.sm),
                child: GeneralRequestThumbnail(
                  imageUrl: thumbnail,
                  size: 96,
                  icon: _iconForTaskType(request.taskPolicy.type),
                ),
              ),
              const SizedBox(width: TtmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TtmTypography.title.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: TtmSpacing.sm),
                        Text(
                          formatRelativeTimeKo(request.createdAt),
                          style: TtmTypography.label.copyWith(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                        request.taskPolicy.type.label,
                        style: TtmTypography.label.copyWith(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TtmTypography.body.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.rewardLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TtmTypography.moneyDisplay.copyWith(
                              fontSize: 18,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        if (taskMinutes > 0) ...[
                          const SizedBox(width: TtmSpacing.xs),
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$taskMinutes분',
                            style: TtmTypography.label.copyWith(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: TtmSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$commentCount',
                          style: TtmTypography.label.copyWith(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: TtmSpacing.md),
                        Icon(
                          Icons.people_alt_outlined,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$applicationCount',
                          style: TtmTypography.label.copyWith(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (onApply != null) ...[
                      const SizedBox(height: TtmSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: FilledButton(
                          onPressed: busy ? null : onApply,
                          style: FilledButton.styleFrom(
                            backgroundColor: applied
                                ? colors.tertiaryContainer
                                : null,
                            foregroundColor: applied
                                ? colors.onTertiaryContainer
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                TtmRadius.pill,
                              ),
                            ),
                            textStyle: TtmTypography.button.copyWith(
                              fontSize: 13,
                            ),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      applied
                                          ? Icons.check_circle_rounded
                                          : Icons.send_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(applied ? '지원함' : '지원하기'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForTaskType(RequestTaskType type) {
    return switch (type.id) {
      'delivery' => Icons.local_shipping_outlined,
      'purchase' => Icons.shopping_bag_outlined,
      'cleaning' => Icons.cleaning_services_outlined,
      'waiting' => Icons.schedule_rounded,
      'pet' => Icons.favorite_border_rounded,
      _ => Icons.forum_rounded,
    };
  }
}

class GeneralRequestThumbnail extends StatelessWidget {
  const GeneralRequestThumbnail({
    super.key,
    required this.imageUrl,
    required this.size,
    this.icon = Icons.forum_rounded,
  });

  final String? imageUrl;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: colors.primaryContainer.withValues(alpha: 0.42),
        child: Icon(icon, color: colors.primary, size: size * 0.34),
      );
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: colors.surfaceContainerHighest,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: colors.onSurfaceVariant,
          size: size * 0.3,
        ),
      ),
    );
  }
}
