import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/restriction_error_message.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../features/settings/settings_copy.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../auth/theme/auth_field_style.dart';
import '../profile_copy.dart';

class NicknameEditScreen extends ConsumerStatefulWidget {
  const NicknameEditScreen({super.key, required this.initialNickname});

  final String initialNickname;

  @override
  ConsumerState<NicknameEditScreen> createState() => _NicknameEditScreenState();
}

class _NicknameEditScreenState extends ConsumerState<NicknameEditScreen> {
  late final TextEditingController _ctl;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool _valid(String s) {
    final t = s.trim();
    return t.length >= 2 && t.length <= 12;
  }

  Future<void> _save() async {
    final next = _ctl.text.trim();
    if (!_valid(next)) {
      setState(() => _error = ProfileCopy.nicknameInvalid);
      return;
    }
    if (next == widget.initialNickname) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(userRepositoryProvider);
      final available = await repo.isNicknameAvailable(next);
      if (!available) {
        if (mounted) setState(() => _error = ProfileCopy.nicknameDuplicate);
        return;
      }
      await repo.updateMyNickname(next);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(SettingsCopy.saveSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      Navigator.of(context).pop();
    } catch (e) {
      final moderationMsg = restrictionErrorMessage(e);
      if (mounted) {
        setState(
          () => _error = moderationMsg.isNotEmpty
              ? moderationMsg
              : SettingsCopy.saveFailure,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(ProfileCopy.nicknameScreenTitle),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(TtmSpacing.xl),
        children: [
          TextField(
            controller: _ctl,
            maxLength: 12,
            decoration: ttmAuthInputDecoration(
              context,
              label: '닉네임',
              hint: ProfileCopy.nicknameHint,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: TtmSpacing.sm),
            Text(
              _error!,
              style: TtmTypography.body.copyWith(
                color: TtmColors.accent,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: TtmSpacing.xxl),
          TTMButton(
            label: ProfileCopy.nicknameSave,
            busy: _busy,
            onPressed: _busy ? null : _save,
          ),
          const SizedBox(height: TtmSpacing.md),
          Text(
            ProfileCopy.nicknameHint,
            style: TtmTypography.body.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
