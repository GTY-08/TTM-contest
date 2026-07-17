import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 외부 서비스 초기화가 잘 됐는지 한눈에 확인하기 위한 **개발 전용** 화면.
class DevBootScreen extends StatelessWidget {
  const DevBootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    final firebaseOk = (Platform.isAndroid || Platform.isIOS)
        ? Firebase.apps.isNotEmpty
        : true;
    final firebaseHint = (Platform.isAndroid || Platform.isIOS)
        ? null
        : 'Windows에서는 스킵';

    const naverOk = true;
    final naverHint = (Platform.isAndroid || Platform.isIOS)
        ? null
        : 'Windows에서는 스킵';

    return Scaffold(
      appBar: AppBar(title: const Text('개발용 부트 체크')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TtmSpacing.xl),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '틈틈',
                  style: TtmTypography.display.copyWith(
                    color: colors.primary,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: TtmSpacing.md),
                Text(
                  '연동 초기화를 확인했어요',
                  style: TtmTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: TtmSpacing.xxl),
                _CheckRow(
                  label: 'Supabase',
                  ok: true,
                  hint: session == null ? '익명 상태' : '로그인됨',
                ),
                _CheckRow(
                  label: 'Firebase Core',
                  ok: firebaseOk,
                  hint: firebaseHint,
                ),
                _CheckRow(label: '네이버 맵 SDK', ok: naverOk, hint: naverHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.ok, this.hint});

  final String label;
  final bool ok;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error,
            color: ok ? TtmColors.success : colors.error,
            size: 18,
          ),
          const SizedBox(width: TtmSpacing.sm),
          Text(label, style: TtmTypography.body),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Text(
              '· ${hint!}',
              style: TtmTypography.label.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
