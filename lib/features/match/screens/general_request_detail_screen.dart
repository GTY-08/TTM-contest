import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/restriction_error_message.dart';
import '../../../data/providers/auth_providers.dart';
import '../../home/widgets/general_request_post_card.dart';
import '../../profile/widgets/profile_photo_change.dart';
import '../models/general_request_post.dart';
import '../models/worker_notification.dart';
import '../providers/match_providers.dart';

class GeneralRequestDetailScreen extends ConsumerStatefulWidget {
  const GeneralRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<GeneralRequestDetailScreen> createState() =>
      _GeneralRequestDetailScreenState();
}

class _GeneralRequestDetailScreenState
    extends ConsumerState<GeneralRequestDetailScreen> {
  final _commentController = TextEditingController();
  final Set<String> _applyingRequestIds = {};
  bool _busy = false;
  bool _commentBusy = false;
  bool _deleting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _apply([String? targetRequestId]) async {
    final requestId = targetRequestId ?? widget.requestId;
    if (_applyingRequestIds.contains(requestId)) return;
    final messageController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('지원하기'),
        content: TextField(
          controller: messageController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '요청자에게 보낼 말',
            hintText: '가능한 시간, 경험, 조율할 내용을 적어 주세요.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지원'),
          ),
        ],
      ),
    );
    final message = messageController.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messageController.dispose();
    });
    if (ok != true || !mounted) return;

    setState(() {
      _applyingRequestIds.add(requestId);
      if (requestId == widget.requestId) _busy = true;
    });
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .applyGeneralRequest(
            requestId,
            initialMessage: message.isEmpty ? null : message,
          );
      if (!mounted) return;
      if (res['ok'] == true) {
        ref.invalidate(generalRequestDetailProvider(requestId));
        ref.invalidate(recommendedGeneralRequestsProvider(widget.requestId));
        ref.invalidate(myGeneralApplicationsProvider);
        final applicationId = res['application_id']?.toString();
        if (applicationId != null && applicationId.isNotEmpty) {
          context.push(
            '${AppRoutes.requestRoot}/$requestId/applications/$applicationId/chat',
          );
        }
      } else {
        _snack('지원하지 못했습니다. (${res['reason'] ?? 'unknown'})');
      }
    } catch (e) {
      final moderationMsg = restrictionErrorMessage(e);
      if (mounted) {
        _snack(
          moderationMsg.isNotEmpty ? moderationMsg : '지원 중 오류가 발생했습니다: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _applyingRequestIds.remove(requestId);
          if (requestId == widget.requestId) _busy = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _commentBusy) return;
    setState(() => _commentBusy = true);
    try {
      await ref
          .read(matchingRepositoryProvider)
          .addGeneralRequestComment(requestId: widget.requestId, content: text);
      _commentController.clear();
      ref.invalidate(generalRequestCommentsProvider(widget.requestId));
      ref.invalidate(generalRequestDetailProvider(widget.requestId));
    } catch (e) {
      final moderationMsg = restrictionErrorMessage(e);
      if (mounted) {
        _snack(moderationMsg.isNotEmpty ? moderationMsg : '댓글을 등록하지 못했습니다: $e');
      }
    } finally {
      if (mounted) setState(() => _commentBusy = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('삭제된 댓글은 내용이 가려집니다. 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(matchingRepositoryProvider)
          .deleteGeneralRequestComment(commentId);
      ref.invalidate(generalRequestCommentsProvider(widget.requestId));
      ref.invalidate(generalRequestDetailProvider(widget.requestId));
    } catch (e) {
      if (mounted) _snack('댓글을 삭제하지 못했습니다: $e');
    }
  }

  Future<void> _deletePost() async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text(
          '아직 작업자가 선택되지 않은 일반 매칭 게시글만 삭제할 수 있어요.\n'
          '일반적인 게시글 삭제에는 페널티가 적용되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final res = await ref
          .read(matchingRepositoryProvider)
          .deleteGeneralRequestPost(widget.requestId);
      if (!mounted) return;
      if (res['ok'] == true) {
        ref.invalidate(myOpenGeneralRequestsProvider);
        ref.invalidate(myPendingNotificationsProvider);
        ref.invalidate(generalRequestDetailProvider(widget.requestId));
        _snack('게시글을 삭제했습니다.');
        context.go(AppRoutes.home);
      } else {
        _snack('게시글을 삭제하지 못했습니다. (${res['reason'] ?? 'unknown'})');
      }
    } catch (e) {
      if (mounted) _snack('게시글 삭제 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _reportComment(String commentId) async {
    var category = 'abuse';
    final descriptionController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('댓글 신고'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('스팸/도배')),
                  DropdownMenuItem(value: 'abuse', child: Text('욕설/비방')),
                  DropdownMenuItem(value: 'privacy', child: Text('개인정보 노출')),
                  DropdownMenuItem(value: 'unsafe', child: Text('위험한 내용')),
                  DropdownMenuItem(value: 'other', child: Text('기타')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => category = value);
                  }
                },
              ),
              const SizedBox(height: TtmSpacing.md),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '추가 설명',
                  hintText: '상황을 간단히 적어 주세요.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );
    final description = descriptionController.text.trim();
    descriptionController.dispose();
    if (ok != true) return;
    try {
      await ref
          .read(matchingRepositoryProvider)
          .reportGeneralRequestComment(
            commentId: commentId,
            category: category,
            description: description.isEmpty ? null : description,
          );
      if (mounted) _snack('신고가 접수되었습니다.');
    } catch (e) {
      final moderationMsg = restrictionErrorMessage(e);
      if (mounted) {
        _snack(moderationMsg.isNotEmpty ? moderationMsg : '신고를 접수하지 못했습니다: $e');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      generalRequestDetailProvider(widget.requestId),
    );
    final commentsAsync = ref.watch(
      generalRequestCommentsProvider(widget.requestId),
    );
    final recommendationsAsync = ref.watch(
      recommendedGeneralRequestsProvider(widget.requestId),
    );
    final uid = ref.watch(authUserIdProvider);

    return detailAsync.when(
      loading: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('게시글')),
        body: Center(child: Text('게시글을 불러오지 못했습니다.\n$e')),
      ),
      data: (detail) {
        final request = detail.request;
        final isOwner = request.requesterId == uid;
        final applicationId = detail.myApplicationId;
        return Scaffold(
          appBar: AppBar(
            title: const Text('일반 매칭'),
            actions: [
              IconButton(
                tooltip: '홈',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go(AppRoutes.home),
              ),
              if (isOwner && request.isOpen)
                IconButton(
                  tooltip: '수정',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => context.push(
                    '${AppRoutes.requestRoot}/${widget.requestId}/edit',
                  ),
                ),
              if (isOwner && request.isOpen)
                IconButton(
                  tooltip: '삭제',
                  icon: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  onPressed: _deleting ? null : () => unawaited(_deletePost()),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.sm,
              TtmSpacing.lg,
              TtmSpacing.lg,
            ),
            child: isOwner
                ? request.isOpen
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => context.push(
                                  '${AppRoutes.requestRoot}/${widget.requestId}/waiting',
                                ),
                                icon: const Icon(Icons.people_alt_outlined),
                                label: Text('지원자 ${detail.applicationCount}명'),
                              ),
                            ),
                            const SizedBox(width: TtmSpacing.sm),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => context.push(
                                  '${AppRoutes.requestRoot}/${widget.requestId}/edit',
                                ),
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('수정'),
                              ),
                            ),
                          ],
                        )
                      : FilledButton.icon(
                          onPressed: request.isMatched
                              ? () => context.go(
                                  '${AppRoutes.requestRoot}/${widget.requestId}/active',
                                )
                              : () => context.go(AppRoutes.home),
                          icon: Icon(
                            request.isMatched
                                ? Icons.play_circle_outline_rounded
                                : Icons.home_outlined,
                          ),
                          label: Text(
                            request.isMatched ? '진행 화면 열기' : '홈으로 이동',
                          ),
                        )
                : FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : applicationId != null
                        ? () => context.push(
                            '${AppRoutes.requestRoot}/${widget.requestId}/applications/$applicationId/chat',
                          )
                        : () => unawaited(_apply()),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            applicationId != null
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.send_rounded,
                          ),
                    label: Text(applicationId != null ? '지원 채팅 보기' : '지원하기'),
                  ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(generalRequestDetailProvider(widget.requestId));
              ref.invalidate(generalRequestCommentsProvider(widget.requestId));
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _PostImages(images: detail.images),
                Padding(
                  padding: const EdgeInsets.all(TtmSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RequesterHeader(requester: detail.requester),
                      const SizedBox(height: TtmSpacing.lg),
                      Text(
                        request.displayTitle,
                        style: TtmTypography.title.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: TtmSpacing.sm),
                      Text(
                        _money(request.reward),
                        style: TtmTypography.moneyDisplay.copyWith(
                          fontSize: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: TtmSpacing.md),
                      Wrap(
                        spacing: TtmSpacing.xs,
                        runSpacing: TtmSpacing.xs,
                        children: [
                          for (final tag in request.tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: TtmSpacing.lg),
                      Text(
                        request.description,
                        style: TtmTypography.body.copyWith(
                          fontSize: 16,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: TtmSpacing.xl),
                      _MetaGrid(
                        estimatedMinutes: request.estimatedTaskMinutes,
                        comments: detail.commentCount,
                        applicants: detail.applicationCount,
                      ),
                      const SizedBox(height: TtmSpacing.xl),
                      _CommentSection(
                        commentsAsync: commentsAsync,
                        currentUserId: uid,
                        controller: _commentController,
                        busy: _commentBusy,
                        onSend: () => unawaited(_addComment()),
                        onDelete: (id) => unawaited(_deleteComment(id)),
                        onReport: (id) => unawaited(_reportComment(id)),
                      ),
                      const SizedBox(height: TtmSpacing.xl),
                      _RecommendedGeneralRequestsSection(
                        async: recommendationsAsync,
                        applyingIds: _applyingRequestIds,
                        onOpen: (requestId) => context.push(
                          '${AppRoutes.requestRoot}/$requestId/general',
                        ),
                        onApply: (requestId) => unawaited(_apply(requestId)),
                        onOpenApplication: (requestId, applicationId) =>
                            context.push(
                              '${AppRoutes.requestRoot}/$requestId/applications/$applicationId/chat',
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _money(num value) {
    return '${NumberFormat.decimalPattern('ko').format(value)}원';
  }
}

class _PostImages extends StatelessWidget {
  const _PostImages({required this.images});

  final List<GeneralRequestPostImage> images;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.35,
        child: Container(
          color: colors.surfaceContainerHighest,
          child: Icon(
            Icons.image_outlined,
            size: 56,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 1.15,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(images[index].imageUrl, fit: BoxFit.cover),
              Positioned(
                right: TtmSpacing.md,
                bottom: TtmSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(TtmRadius.pill),
                  ),
                  child: Text(
                    '${index + 1}/${images.length}',
                    style: TtmTypography.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequesterHeader extends StatelessWidget {
  const _RequesterHeader({required this.requester});

  final Map<String, dynamic> requester;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final nickname = requester['nickname']?.toString() ?? '요청자';
    final rating = requester['rating']?.toString() ?? '-';
    return Row(
      children: [
        TtmProfileAvatar(
          imageUrl: requester['profile_image_url']?.toString(),
          size: 42,
        ),
        const SizedBox(width: TtmSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nickname,
                style: TtmTypography.title.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '평점 $rating',
                style: TtmTypography.body.copyWith(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({
    required this.estimatedMinutes,
    required this.comments,
    required this.applicants,
  });

  final int estimatedMinutes;
  final int comments;
  final int applicants;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TtmSpacing.sm,
      runSpacing: TtmSpacing.sm,
      children: [
        _MetaChip(icon: Icons.timer_outlined, text: '예상 $estimatedMinutes분'),
        _MetaChip(
          icon: Icons.chat_bubble_outline_rounded,
          text: '댓글 $comments',
        ),
        _MetaChip(icon: Icons.people_alt_outlined, text: '지원 $applicants'),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(TtmRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            text,
            style: TtmTypography.label.copyWith(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentSection extends StatelessWidget {
  const _CommentSection({
    required this.commentsAsync,
    required this.currentUserId,
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onDelete,
    required this.onReport,
  });

  final AsyncValue<List<GeneralRequestComment>> commentsAsync;
  final String? currentUserId;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onReport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '댓글',
          style: TtmTypography.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: TtmSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
              ),
            ),
            const SizedBox(width: TtmSpacing.sm),
            FilledButton(
              onPressed: busy ? null : onSend,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('등록'),
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.lg),
        commentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('댓글을 불러오지 못했습니다.\n$e'),
          data: (comments) {
            if (comments.isEmpty) {
              return Text(
                '아직 댓글이 없습니다.',
                style: TtmTypography.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: [
                for (final comment in comments) ...[
                  _CommentTile(
                    comment: comment,
                    isMine: comment.authorId == currentUserId,
                    onDelete: () => onDelete(comment.id),
                    onReport: () => onReport(comment.id),
                  ),
                  const Divider(height: 1),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onDelete,
    required this.onReport,
  });

  final GeneralRequestComment comment;
  final bool isMine;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TtmSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TtmProfileAvatar(imageUrl: comment.authorProfileImageUrl, size: 34),
          const SizedBox(width: TtmSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorNickname,
                  style: TtmTypography.label.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.isDeleted ? '삭제된 댓글입니다.' : comment.content,
                  style: TtmTypography.body.copyWith(
                    color: comment.isDeleted
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                    fontStyle: comment.isDeleted ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
          ),
          if (!comment.isDeleted)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') onDelete();
                if (value == 'report') onReport();
              },
              itemBuilder: (context) => [
                if (isMine)
                  const PopupMenuItem(value: 'delete', child: Text('삭제')),
                if (!isMine)
                  const PopupMenuItem(value: 'report', child: Text('신고')),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecommendedGeneralRequestsSection extends StatelessWidget {
  const _RecommendedGeneralRequestsSection({
    required this.async,
    required this.applyingIds,
    required this.onOpen,
    required this.onApply,
    required this.onOpenApplication,
  });

  final AsyncValue<List<WorkerNotification>> async;
  final Set<String> applyingIds;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onApply;
  final void Function(String requestId, String applicationId) onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '이런 작업도 맞을 수 있어요',
                style: TtmTypography.title.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.auto_awesome_rounded, size: 20, color: colors.primary),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '비슷한 태그와 최근 지원한 작업 유형을 기준으로 골랐어요.',
          style: TtmTypography.body.copyWith(
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TtmSpacing.md),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: TtmSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(TtmSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(TtmRadius.md),
                ),
                child: Text(
                  '아직 추천할 만한 일반 작업이 없어요.',
                  style: TtmTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  GeneralRequestPostCard(
                    notification: item,
                    busy: applyingIds.contains(item.requestId),
                    applied: item.hasMyGeneralApplication,
                    onTap: () => onOpen(item.requestId),
                    onApply: item.hasMyGeneralApplication
                        ? () {
                            final applicationId = item.myApplicationId;
                            if (applicationId != null &&
                                applicationId.isNotEmpty) {
                              onOpenApplication(item.requestId, applicationId);
                            }
                          }
                        : () => onApply(item.requestId),
                  ),
                  const SizedBox(height: TtmSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
