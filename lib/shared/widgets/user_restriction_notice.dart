import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/user_restriction.dart';
import '../../data/providers/auth_providers.dart';

class UserRestrictionNotice extends ConsumerStatefulWidget {
  const UserRestrictionNotice({
    super.key,
    this.onlyBlockingRequest = false,
    this.onlyBlockingWorker = false,
    this.onlyBlockingChat = false,
    this.compact = false,
  });

  final bool onlyBlockingRequest;
  final bool onlyBlockingWorker;
  final bool onlyBlockingChat;
  final bool compact;

  @override
  ConsumerState<UserRestrictionNotice> createState() =>
      _UserRestrictionNoticeState();
}

class _UserRestrictionNoticeState extends ConsumerState<UserRestrictionNotice> {
  static const _rotationInterval = Duration(seconds: 8);
  static const _transitionDuration = Duration(milliseconds: 280);

  Timer? _timer;
  int _index = 0;
  int _lastCount = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncRotation(int count) {
    if (_lastCount != count) {
      _index = 0;
      _lastCount = count;
      _timer?.cancel();
      _timer = null;
    }

    if (count <= 1) {
      _timer?.cancel();
      _timer = null;
      _index = 0;
      return;
    }

    if (_index >= count) _index = 0;
    _timer ??= Timer.periodic(_rotationInterval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final restrictions =
        ref.watch(myActiveRestrictionsProvider).valueOrNull ?? const [];
    final visible = restrictions
        .where((item) {
          if (widget.onlyBlockingRequest) return item.blocksRequest;
          if (widget.onlyBlockingWorker) return item.blocksWorker;
          if (widget.onlyBlockingChat) return item.blocksChat;
          return true;
        })
        .toList(growable: false);

    if (visible.isEmpty) {
      _syncRotation(0);
      return const SizedBox.shrink();
    }

    _syncRotation(visible.length);
    final primary = visible[_index.clamp(0, visible.length - 1)];
    final colors = Theme.of(context).colorScheme;
    final isCritical =
        primary.isSuspended ||
        primary.blocksRequest ||
        primary.blocksWorker ||
        primary.blocksChat;
    final background = isCritical
        ? colors.errorContainer.withValues(alpha: 0.92)
        : colors.tertiaryContainer.withValues(alpha: 0.92);
    final foreground = isCritical
        ? colors.onErrorContainer
        : colors.onTertiaryContainer;

    return AnimatedSwitcher(
      duration: _transitionDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Container(
        key: ValueKey(primary.id),
        padding: EdgeInsets.all(widget.compact ? TtmSpacing.md : TtmSpacing.lg),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: foreground.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              primary.isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.block_rounded,
              color: foreground,
            ),
            const SizedBox(width: TtmSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(primary),
                    style: TtmTypography.title.copyWith(
                      fontSize: widget.compact ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.xs),
                  Text(
                    _body(primary),
                    style: TtmTypography.body.copyWith(
                      fontSize: widget.compact ? 13 : 14,
                      height: 1.45,
                      color: foreground.withValues(alpha: 0.92),
                    ),
                  ),
                  if (!widget.compact && visible.length > 1) ...[
                    const SizedBox(height: TtmSpacing.sm),
                    Text(
                      '${_index + 1} / ${visible.length}개의 제재가 적용 중입니다.',
                      style: TtmTypography.body.copyWith(
                        fontSize: 13,
                        color: foreground.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(UserRestriction restriction) {
    return switch (restriction.type) {
      'suspended' => '계정 이용 정지 적용 중',
      'request_block' => '심부름 요청 기능 제한 중',
      'worker_block' => '작업 수락 기능 제한 중',
      'matching_block' => '신규 매칭 활동 제한 중',
      'chat_block' => '채팅 기능 제한 중',
      'warning' => '운영 경고가 적용되었습니다',
      _ => '이용 제한이 적용 중입니다',
    };
  }

  String _body(UserRestriction restriction) {
    return '${restriction.displayReason}${_untilText(restriction.endsAt)}';
  }

  String _untilText(DateTime? value) {
    if (value == null) return '\n해제 예정 시간이 정해지지 않았습니다.';
    final local = value.toLocal();
    final yyyy = local.year.toString();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '\n해제 예정: $yyyy.$mm.$dd $hh:$mi';
  }
}
