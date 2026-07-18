import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/auth_providers.dart';
import '../providers/raid_providers.dart';

class RaidChatScreen extends ConsumerStatefulWidget {
  const RaidChatScreen({super.key, required this.raidId});
  final String raidId;
  @override
  ConsumerState<RaidChatScreen> createState() => _RaidChatScreenState();
}

class _RaidChatScreenState extends ConsumerState<RaidChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(raidRepositoryProvider).markChatRead(widget.raidId),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(raidMessagesProvider(widget.raidId));
    final detail = ref.watch(raidDetailProvider(widget.raidId)).valueOrNull;
    final uid = ref.watch(authUserIdProvider);
    final readOnly =
        detail == null ||
        {'completed', 'cancelled'}.contains(detail.raid.status);
    final names = {
      for (final p in detail?.participants ?? const [])
        p.userId: p.nickname ?? '참가자',
    };
    return Scaffold(
      appBar: AppBar(title: Text(detail?.raid.title ?? '레이드 단체 DM')),
      body: Column(
        children: [
          if (readOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(TtmSpacing.sm),
              color: TtmColors.primary.withValues(alpha: 0.08),
              child: const Text(
                '종료된 레이드의 대화 기록이에요.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('대화를 불러오지 못했어요.')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('첫 인사를 건네 보세요.'))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(TtmSpacing.md),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final message = items[items.length - 1 - index];
                        final mine = message.senderId == uid;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: TtmSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 3,
                                    ),
                                    child: Text(
                                      names[message.senderId] ?? '참가자',
                                      style: TtmTypography.label,
                                    ),
                                  ),
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? TtmColors.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    message.content,
                                    style: TtmTypography.body.copyWith(
                                      color: mine ? Colors.white : null,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    left: 4,
                                    right: 4,
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'HH:mm',
                                    ).format(message.createdAt),
                                    style: TtmTypography.label.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (!readOnly)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TtmSpacing.md,
                  TtmSpacing.sm,
                  TtmSpacing.md,
                  TtmSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '메시지를 입력하세요',
                        ),
                      ),
                    ),
                    const SizedBox(width: TtmSpacing.sm),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(raidRepositoryProvider).sendMessage(widget.raidId, text);
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('메시지를 보내지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
