import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_empty_state.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';

class RaidRewardTab extends ConsumerStatefulWidget {
  const RaidRewardTab({super.key});

  @override
  ConsumerState<RaidRewardTab> createState() => _RaidRewardTabState();
}

class _RaidRewardTabState extends ConsumerState<RaidRewardTab> {
  int _segment = 0;
  String? _redeemingId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        TtmSpacing.md,
        TtmSpacing.lg,
        120,
      ),
      children: [
        Text('리워드', style: TtmTypography.display.copyWith(fontSize: 24)),
        const SizedBox(height: TtmSpacing.md),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('포인트샵'),
              icon: Icon(Icons.redeem_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('참가비·정산'),
              icon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ],
          selected: {_segment},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => _segment = value.first),
        ),
        const SizedBox(height: TtmSpacing.lg),
        if (_segment == 0) _pointShop() else _feeWallet(),
      ],
    );
  }

  Widget _pointShop() {
    final summary = ref.watch(rewardSummaryProvider);
    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const TtmEmptyState(
        title: '리워드를 불러오지 못했어요',
        subtitle: '잠시 후 다시 확인해 주세요.',
        iconAsset: 'assets/icons/star.svg',
      ),
      data: (data) {
        final number = NumberFormat.decimalPattern('ko');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TtmTierCard(
              tier: TtmCardTier.mission,
              padding: const EdgeInsets.all(TtmSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '보유 포인트',
                    style: TtmTypography.label.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${number.format(data.availablePoints)}P',
                    style: TtmTypography.moneyDisplay.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: TtmSpacing.md),
                  Row(
                    children: [
                      Text(
                        'Lv.${data.level} ${data.levelTitle}',
                        style: TtmTypography.title.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '누적 ${number.format(data.lifetimePoints)}P',
                        style: TtmTypography.label.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: data.levelProgress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TtmSpacing.xl),
            Text(
              '교환 가능한 리워드',
              style: TtmTypography.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: TtmSpacing.sm),
            for (final item in data.catalog) ...[
              _RewardItemCard(
                item: item,
                canRedeem:
                    data.availablePoints >= item.pointCost && item.stock > 0,
                busy: _redeemingId == item.id,
                onRedeem: () => _confirmRedeem(item),
              ),
              const SizedBox(height: TtmSpacing.sm),
            ],
            const SizedBox(height: TtmSpacing.xl),
            Text('교환 내역', style: TtmTypography.title.copyWith(fontSize: 18)),
            const SizedBox(height: TtmSpacing.sm),
            if (data.redemptions.isEmpty)
              const Text('아직 교환한 리워드가 없어요.')
            else
              for (final item in data.redemptions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.card_giftcard_rounded),
                  ),
                  title: Text(item['item_name']?.toString() ?? '리워드'),
                  subtitle: Text(item['issue_code']?.toString() ?? ''),
                  trailing: const Text('사용 가능'),
                ),
          ],
        );
      },
    );
  }

  Widget _feeWallet() {
    final wallet = ref.watch(raidFeeWalletProvider);
    return wallet.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const TtmEmptyState(
        title: '참가비 내역을 불러오지 못했어요',
        subtitle: '잠시 후 다시 확인해 주세요.',
        iconAsset: 'assets/icons/card.svg',
      ),
      data: (data) {
        final rawWallet = Map<String, dynamic>.from(
          (data['wallet'] as Map?) ?? const {},
        );
        final number = NumberFormat.decimalPattern('ko');
        int amount(Object? value) =>
            value is num ? value.round() : int.tryParse('$value') ?? 0;
        final tx = ((data['raid_fee_transactions'] as List?) ?? const [])
            .whereType<Map>()
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TtmTierCard(
              tier: TtmCardTier.status,
              padding: const EdgeInsets.all(TtmSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('참가비 지갑', style: TtmTypography.title),
                  const SizedBox(height: TtmSpacing.sm),
                  Text(
                    '${number.format(amount(rawWallet['balance']))}원',
                    style: TtmTypography.moneyDisplay.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: TtmSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _WalletMetric(
                          label: '보관 중',
                          value:
                              '${number.format(amount(rawWallet['escrow_hold']))}원',
                        ),
                      ),
                      Expanded(
                        child: _WalletMetric(
                          label: '누적 정산',
                          value:
                              '${number.format(amount(rawWallet['total_earned']))}원',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: TtmSpacing.xl),
            Text('최근 내역', style: TtmTypography.title.copyWith(fontSize: 18)),
            const SizedBox(height: TtmSpacing.sm),
            if (tx.isEmpty)
              const Text('아직 참가비 내역이 없어요.')
            else
              for (final item in tx)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: TtmColors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      _feeIcon(item['direction']?.toString()),
                      color: TtmColors.primary,
                    ),
                  ),
                  title: Text(_feeLabel(item['reason']?.toString())),
                  subtitle: Text(
                    DateFormat('M월 d일 HH:mm', 'ko').format(
                      DateTime.tryParse(
                            item['created_at']?.toString() ?? '',
                          )?.toLocal() ??
                          DateTime.now(),
                    ),
                  ),
                  trailing: Text(
                    '${number.format(amount(item['amount']))}원',
                    style: TtmTypography.metric,
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRedeem(RewardCatalogItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리워드를 교환할까요?'),
        content: Text(
          '${item.name}\n${NumberFormat.decimalPattern('ko').format(item.pointCost)}P가 사용됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('교환'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _redeemingId = item.id);
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .redeemReward(item.id);
      if (!mounted) return;
      if (result['ok'] == true) {
        ref.invalidate(rewardSummaryProvider);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('교환이 완료됐어요'),
            content: SelectableText('발급 코드\n${result['issue_code'] ?? ''}'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        _show(switch (result['reason']) {
          'insufficient_points' => '포인트가 부족해요.',
          'out_of_stock' => '준비된 수량이 모두 소진됐어요.',
          _ => '교환하지 못했어요.',
        });
      }
    } catch (_) {
      if (mounted) _show('교환하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _redeemingId = null);
    }
  }

  void _show(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

class _RewardItemCard extends StatelessWidget {
  const _RewardItemCard({
    required this.item,
    required this.canRedeem,
    required this.busy,
    required this.onRedeem,
  });
  final RewardCatalogItem item;
  final bool canRedeem;
  final bool busy;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(item.accentColor);
    return TtmTierCard(
      tier: TtmCardTier.feed,
      padding: const EdgeInsets.all(TtmSpacing.md),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_rewardIcon(item.iconKey), color: color, size: 28),
          ),
          const SizedBox(width: TtmSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TtmTypography.title.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  '${NumberFormat.decimalPattern('ko').format(item.pointCost)}P · 남은 수량 ${item.stock}',
                  style: TtmTypography.label.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TTMButton(
            label: item.stock <= 0 ? '품절' : '교환',
            onPressed: canRedeem ? onRedeem : null,
            busy: busy,
            expanded: false,
            pill: false,
          ),
        ],
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TtmTypography.label),
      const SizedBox(height: 3),
      Text(value, style: TtmTypography.metric),
    ],
  );
}

Color _parseColor(String value) {
  final hex = value.replaceFirst('#', '');
  return Color(int.tryParse('FF$hex', radix: 16) ?? 0xFF0B7A75);
}

IconData _rewardIcon(String key) => switch (key) {
  'sports_drink' => Icons.local_drink_outlined,
  'convenience' => Icons.storefront_outlined,
  'coffee' => Icons.coffee_outlined,
  'culture' => Icons.menu_book_outlined,
  _ => Icons.card_giftcard_rounded,
};

IconData _feeIcon(String? direction) => switch (direction) {
  'credit' => Icons.south_west_rounded,
  'refund' => Icons.replay_rounded,
  _ => Icons.lock_outline_rounded,
};

String _feeLabel(String? reason) => switch (reason) {
  'organizer_settlement' => '레이드 정산',
  'raid_refund' => '참가비 환불',
  _ => '참가비 보관',
};
