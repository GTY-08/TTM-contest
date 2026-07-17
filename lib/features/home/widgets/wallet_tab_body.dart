import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../core/theme/ttm_semantic_colors.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_tier_card.dart';

class WalletTabBody extends ConsumerStatefulWidget {
  const WalletTabBody({super.key});

  @override
  ConsumerState<WalletTabBody> createState() => _WalletTabBodyState();
}

class _WalletTabBodyState extends ConsumerState<WalletTabBody> {
  bool _charging = false;

  Future<void> _chargeDemoWallet() async {
    if (_charging) return;
    setState(() => _charging = true);

    try {
      final result = await ref
          .read(demoWalletRepositoryProvider)
          .chargeMyWallet();
      if (!mounted) return;

      if (result['ok'] == true) {
        ref.invalidate(myDemoWalletProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('데모 잔액 100,000원이 충전됐어요.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('충전하지 못했어요. ${result['reason'] ?? ''}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('충전하지 못했어요. $error')));
    } finally {
      if (mounted) {
        setState(() => _charging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(myDemoWalletProvider);
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final money = NumberFormat.decimalPattern('ko');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myDemoWalletProvider);
      },
      child: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(TtmSpacing.lg),
          children: [
            const SizedBox(height: 120),
            Text('지갑 정보를 불러오지 못했어요.', style: TtmTypography.title),
            const SizedBox(height: TtmSpacing.sm),
            Text('$error', style: TtmTypography.body),
          ],
        ),
        data: (data) {
          final wallet = Map<String, dynamic>.from(
            (data['wallet'] as Map?) ?? const {},
          );
          final transactions = ((data['transactions'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
          final balance = _num(wallet['balance']);
          final hold = _num(wallet['escrow_hold']);
          final earned = _num(wallet['total_earned']);
          final fees = _num(wallet['total_fees']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.lg,
              TtmSpacing.lg,
              100,
            ),
            children: [
              Text(
                '지갑',
                style: TtmTypography.title.copyWith(
                  fontSize: 24,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TtmSpacing.xs),
              Text(
                '대회 데모용 가상 잔액입니다. 실제 현금 충전·출금은 아직 제공하지 않습니다.',
                style: TtmTypography.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TtmSpacing.lg),
              TtmTierCard(
                tier: TtmCardTier.mission,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '사용 가능 데모 잔액',
                      style: TtmTypography.eyebrow.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.sm),
                    Text(
                      '₩${money.format(balance)}',
                      style: TtmTypography.moneyDisplay.copyWith(
                        fontSize: 38,
                        color: semantic.brandTeal,
                      ),
                    ),
                    const SizedBox(height: TtmSpacing.md),
                    _WalletLine(
                      label: '에스크로 예치 중',
                      value: '₩${money.format(hold)}',
                    ),
                    _WalletLine(
                      label: '작업 지급 누적',
                      value: '₩${money.format(earned)}',
                    ),
                    _WalletLine(
                      label: '수수료 차감 누적',
                      value: '₩${money.format(fees)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TtmSpacing.md),
              TTMButton(
                label: '데모 잔액 충전',
                icon: Icons.add_card_outlined,
                busy: _charging,
                onPressed: _charging ? null : _chargeDemoWallet,
              ),
              const SizedBox(height: TtmSpacing.xs),
              Text(
                '실제 결제 없이 대회 시연용 잔액 100,000원이 추가됩니다.',
                style: TtmTypography.label.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TtmSpacing.md),
              TtmTierCard(
                tier: TtmCardTier.status,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: semantic.brandTeal),
                    const SizedBox(width: TtmSpacing.sm),
                    Expanded(
                      child: Text(
                        '요청을 만들면 보상금이 가상 에스크로로 잠기고, 완료 확인 시 작업자에게 수수료를 뺀 금액이 지급됩니다. 취소되면 요청자에게 환불됩니다.',
                        style: TtmTypography.body.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TtmSpacing.lg),
              Text('최근 내역', style: TtmTypography.title),
              const SizedBox(height: TtmSpacing.sm),
              if (transactions.isEmpty)
                TtmTierCard(
                  tier: TtmCardTier.feed,
                  child: Text(
                    '아직 지갑 내역이 없어요.',
                    style: TtmTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final tx in transactions) ...[
                  _TransactionTile(tx: tx),
                  const SizedBox(height: TtmSpacing.sm),
                ],
            ],
          );
        },
      ),
    );
  }

  static int _num(Object? value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }
}

class _WalletLine extends StatelessWidget {
  const _WalletLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: TtmSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TtmTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
          Text(value, style: TtmTypography.metric),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final Map<String, dynamic> tx;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = TtmSemanticColors.of(context);
    final money = NumberFormat.decimalPattern('ko');
    final amount = _WalletTabBodyState._num(tx['amount']);
    final direction = tx['direction']?.toString() ?? '';
    final reason = tx['reason']?.toString() ?? '';
    final isPlus = direction == 'credit';
    final isMinus =
        direction == 'hold' || direction == 'debit' || direction == 'fee';
    final sign = isPlus
        ? '+'
        : isMinus
        ? '-'
        : '';

    return TtmTierCard(
      tier: TtmCardTier.feed,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (isPlus ? semantic.brandTeal : colors.primary)
                .withValues(alpha: 0.12),
            child: Icon(
              _icon(reason),
              color: isPlus ? semantic.brandTeal : colors.primary,
            ),
          ),
          const SizedBox(width: TtmSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(reason), style: TtmTypography.title),
                const SizedBox(height: 2),
                Text(
                  tx['memo']?.toString() ?? '',
                  style: TtmTypography.label.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign₩${money.format(amount)}',
            style: TtmTypography.metric.copyWith(
              color: isPlus ? semantic.brandTeal : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(String reason) => switch (reason) {
    'initial_grant' => Icons.card_giftcard,
    'demo_charge' => Icons.add_card_outlined,
    'escrow_hold' || 'escrow_adjust' => Icons.lock_outline,
    'escrow_refund' => Icons.replay_outlined,
    'worker_payout' => Icons.payments_outlined,
    'platform_fee' => Icons.percent,
    _ => Icons.account_balance_wallet_outlined,
  };

  String _label(String reason) => switch (reason) {
    'initial_grant' => '데모 시작 잔액',
    'demo_charge' => '데모 잔액 충전',
    'escrow_hold' => '에스크로 예치',
    'escrow_adjust' => '에스크로 조정',
    'escrow_refund' => '취소 환불',
    'worker_payout' => '작업 지급',
    'platform_fee' => '수수료 차감',
    _ => '지갑 내역',
  };
}
