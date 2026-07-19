import 'dart:convert';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/naver_map_support.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/home_navigation_provider.dart';
import '../../../data/providers/theme_providers.dart';
import '../../../core/utils/ttm_snackbar.dart';
import '../../../features/premium/providers/premium_providers.dart';
import '../../raid/models/exercise_matching_models.dart';
import '../../raid/models/raid_models.dart';
import '../../raid/providers/raid_providers.dart';
import '../../../features/reports/report_repository.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_settings_widgets.dart';
import '../../../shared/widgets/user_restriction_notice.dart';
import '../screens/change_password_screen.dart';
import '../settings_copy.dart';
import '../utils/auth_session_utils.dart';
import '../utils/penalty_format.dart';
import 'settings_choice_chip.dart';

Color _tabBg(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return colors.brightness == Brightness.dark
      ? colors.surface
      : TtmColors.lightBackground;
}

void _snack(BuildContext context, String msg) {
  showTtmSnackBar(context, msg);
}

/// 설정 내부 탭 공통 ListView 패딩.
class SettingsTabScroll extends StatelessWidget {
  const SettingsTabScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _tabBg(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.xl,
          TtmSpacing.lg,
          TtmSpacing.xl,
          TtmSpacing.xxxl,
        ),
        children: children,
      ),
    );
  }
}

// ── 계정 ─────────────────────────────────────────────────────

class SettingsAccountTab extends ConsumerWidget {
  const SettingsAccountTab({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(SettingsCopy.logoutDialogTitle),
        content: const Text(SettingsCopy.logoutDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(SettingsCopy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(SettingsCopy.logoutConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(SettingsCopy.deleteAccountDialogTitle),
        content: const Text(SettingsCopy.deleteAccountDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(SettingsCopy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(SettingsCopy.deleteAccountConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      ref.invalidate(myProfileProvider);
      if (!context.mounted) return;
      _snack(context, SettingsCopy.deleteAccountSuccess);
      context.go(AppRoutes.login);
    } catch (_) {
      if (context.mounted) {
        _snack(context, SettingsCopy.deleteAccountFailure);
      }
    }
  }

  Future<void> _sendResetMail(BuildContext context, WidgetRef ref) async {
    final email = ref.read(supabaseClientProvider).auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      _snack(context, SettingsCopy.resetMailNoEmail);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(SettingsCopy.resetMailDialogTitle),
        content: Text(SettingsCopy.resetMailDialogBody(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(SettingsCopy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('보내기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (context.mounted) _snack(context, SettingsCopy.resetMailSuccess);
    } catch (_) {
      if (context.mounted) _snack(context, SettingsCopy.saveFailure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final hasEmail = sessionHasEmailProvider(user);
    final provider = sessionPrimaryProvider(user);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(SettingsCopy.saveFailure)),
      data: (profile) {
        final email = profile?.email ?? user?.email ?? '—';

        return SettingsTabScroll(
          children: [
            const TtmSettingsInfoBanner(
              title: SettingsCopy.accountBannerTitle,
              body: SettingsCopy.accountBannerBody,
            ),
            const SizedBox(height: TtmSpacing.md),
            const UserRestrictionNotice(),
            const SizedBox(height: TtmSpacing.xl),
            TtmSettingsGroup(
              children: [
                TtmSettingsTile(
                  title: SettingsCopy.loginAccountTitle,
                  subtitle: email,
                  showChevron: false,
                  onTap: null,
                ),
                TtmSettingsTile(
                  title: SettingsCopy.loginProviderTitle,
                  subtitle: providerSubtitle(provider),
                  showChevron: false,
                  onTap: null,
                ),
                TtmSettingsTile(
                  title: SettingsCopy.passwordChangeTitle,
                  subtitle: hasEmail
                      ? SettingsCopy.passwordChangeSubtitle
                      : SettingsCopy.passwordChangeDisabledSubtitle,
                  enabled: hasEmail,
                  onTap: hasEmail
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        )
                      : null,
                ),
                TtmSettingsTile(
                  title: SettingsCopy.passwordResetTitle,
                  subtitle: SettingsCopy.passwordResetSubtitle,
                  enabled: hasEmail,
                  onTap: hasEmail ? () => _sendResetMail(context, ref) : null,
                ),
                TtmSettingsTile(
                  title: SettingsCopy.socialKakaoTitle,
                  subtitle: provider == 'kakao'
                      ? SettingsCopy.socialCurrent
                      : SettingsCopy.socialAvailable,
                  showChevron: false,
                  onTap: null,
                ),
                TtmSettingsTile(
                  title: SettingsCopy.socialGoogleTitle,
                  subtitle: provider == 'google'
                      ? SettingsCopy.socialCurrent
                      : SettingsCopy.socialAvailable,
                  showChevron: false,
                  onTap: null,
                ),
                TtmSettingsTile(
                  title: SettingsCopy.socialAppleTitle,
                  subtitle: provider == 'apple'
                      ? SettingsCopy.socialCurrent
                      : SettingsCopy.socialAppleComingSoon,
                  enabled: false,
                  onTap: null,
                ),
              ],
            ),
            const SizedBox(height: TtmSpacing.xxl),
            TTMButton(
              label: SettingsCopy.logoutButton,
              variant: TtmButtonVariant.ghost,
              onPressed: () => _logout(context, ref),
            ),
            const SizedBox(height: TtmSpacing.md),
            TTMButton(
              label: SettingsCopy.deleteAccountButton,
              variant: TtmButtonVariant.danger,
              onPressed: () => _deleteAccount(context, ref),
            ),
          ],
        );
      },
    );
  }
}

// ── 알림 ─────────────────────────────────────────────────────

class SettingsNotificationsTab extends ConsumerStatefulWidget {
  const SettingsNotificationsTab({super.key});

  @override
  ConsumerState<SettingsNotificationsTab> createState() =>
      _SettingsNotificationsTabState();
}

class _SettingsNotificationsTabState
    extends ConsumerState<SettingsNotificationsTab> {
  bool _saving = false;

  Future<void> _saveMode(String mode) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateNotificationMode(mode);
      ref.invalidate(myProfileProvider);
      if (mounted) _snack(context, SettingsCopy.saveSuccess);
    } catch (_) {
      if (mounted) _snack(context, SettingsCopy.saveFailure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveMarketing(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateMarketingOptIn(value);
      ref.invalidate(myProfileProvider);
      if (mounted) _snack(context, SettingsCopy.saveSuccess);
    } catch (_) {
      if (mounted) _snack(context, SettingsCopy.saveFailure);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final colors = Theme.of(context).colorScheme;

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(SettingsCopy.saveFailure)),
      data: (profile) {
        final mode = profile?.notificationMode ?? 'push';
        final marketing = profile?.marketingOptIn ?? false;

        return SettingsTabScroll(
          children: [
            const TtmSettingsInfoBanner(
              title: SettingsCopy.notifyBannerTitle,
              body: SettingsCopy.notifyBannerBody,
            ),
            const SizedBox(height: TtmSpacing.xl),
            SettingsChoiceChip(
              label: SettingsCopy.notifyModePushTitle,
              subtitle: SettingsCopy.notifyModePushSubtitle,
              selected: mode == 'push',
              onTap: _saving ? () {} : () => _saveMode('push'),
            ),
            const SizedBox(height: TtmSpacing.sm),
            SettingsChoiceChip(
              label: SettingsCopy.notifyModeInAppTitle,
              subtitle: SettingsCopy.notifyModeInAppSubtitle,
              selected: mode == 'push_inapp',
              onTap: _saving ? () {} : () => _saveMode('push_inapp'),
            ),
            const SizedBox(height: TtmSpacing.sm),
            SettingsChoiceChip(
              label: SettingsCopy.notifyModeVibrateTitle,
              subtitle: SettingsCopy.notifyModeVibrateSubtitle,
              selected: mode == 'push_inapp_vibrate',
              onTap: _saving ? () {} : () => _saveMode('push_inapp_vibrate'),
            ),
            const SizedBox(height: TtmSpacing.xl),
            TtmSettingsGroup(
              children: [
                TtmSettingsTile(
                  title: SettingsCopy.notifyPermissionTitle,
                  subtitle: SettingsCopy.notifyPermissionSubtitle,
                  trailing: Text(
                    SettingsCopy.notifyPermissionOpen,
                    style: TtmTypography.label.copyWith(
                      color: TtmColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => AppSettings.openAppSettings(
                    type: AppSettingsType.notification,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TtmSpacing.lg,
                    vertical: TtmSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SettingsCopy.marketingTitle,
                              style: TtmTypography.title.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              SettingsCopy.marketingSubtitle,
                              style: TtmTypography.body.copyWith(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              SettingsCopy.marketingFootnote,
                              style: TtmTypography.body.copyWith(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: marketing,
                        onChanged: _saving ? null : _saveMarketing,
                      ),
                    ],
                  ),
                ),
                TtmSettingsTile(
                  title: SettingsCopy.goNotificationsTitle,
                  subtitle: SettingsCopy.goNotificationsSubtitle,
                  onTap: () {
                    ref.read(homeTabIndexProvider.notifier).state = 2;
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── 작업 ─────────────────────────────────────────────────────

class SettingsWorkerTab extends ConsumerStatefulWidget {
  const SettingsWorkerTab({super.key});

  @override
  ConsumerState<SettingsWorkerTab> createState() => _SettingsWorkerTabState();
}

class _SettingsWorkerTabState extends ConsumerState<SettingsWorkerTab> {
  bool _saving = false;
  String? _exerciseSettingsSignature;
  int _maxDistanceMeters = 5000;
  final Set<String> _selectedExercises = {'walking'};

  void _initializeExerciseSettings(ExercisePreferences preferences) {
    final signature =
        '${preferences.maxDistanceMeters}|${preferences.preferredExercises.join(',')}';
    if (_exerciseSettingsSignature == signature) return;
    _exerciseSettingsSignature = signature;
    _maxDistanceMeters = preferences.maxDistanceMeters;
    _selectedExercises
      ..clear()
      ..addAll(
        preferences.preferredExercises.isEmpty
            ? const ['walking']
            : preferences.preferredExercises,
      );
  }

  Future<void> _saveExerciseSettings({
    required int maxDistanceMeters,
    required Set<String> exercises,
  }) async {
    if (_saving) return;
    final preferences = ref.read(exercisePreferencesProvider).valueOrNull;
    if (preferences == null) {
      _snack(context, SettingsCopy.saveFailure);
      return;
    }
    if (exercises.isEmpty) {
      _snack(context, '선호 운동을 하나 이상 선택해 주세요.');
      return;
    }
    final previousDistance = _maxDistanceMeters;
    final previousExercises = Set<String>.from(_selectedExercises);
    setState(() {
      _saving = true;
      _maxDistanceMeters = maxDistanceMeters;
      _selectedExercises
        ..clear()
        ..addAll(exercises);
    });
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .saveExercisePreferences(
            activityLabel: preferences.activityLabel,
            latitude: preferences.latitude,
            longitude: preferences.longitude,
            exercises: exercises.toList(),
            fitnessLevel: preferences.fitnessLevel,
            availableDays: preferences.availableDays,
            availableStart: preferences.availableStart,
            availableEnd: preferences.availableEnd,
            maxDistanceMeters: maxDistanceMeters,
          );
      if (result['ok'] != true) throw StateError('save_failed');
      ref.invalidate(exercisePreferencesProvider);
      if (mounted) _snack(context, SettingsCopy.saveSuccess);
    } catch (_) {
      if (mounted) {
        setState(() {
          _maxDistanceMeters = previousDistance;
          _selectedExercises
            ..clear()
            ..addAll(previousExercises);
        });
        _snack(context, SettingsCopy.saveFailure);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final preferencesAsync = ref.watch(exercisePreferencesProvider);
    final colors = Theme.of(context).colorScheme;

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(SettingsCopy.saveFailure)),
      data: (profile) => preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(SettingsCopy.saveFailure)),
        data: (preferences) {
          _initializeExerciseSettings(preferences);

          String penaltySubtitle = SettingsCopy.workerPenaltyNone;
          if (profile != null) {
            if (profile.hasActiveRequesterPenalty) {
              penaltySubtitle = SettingsCopy.workerPenaltyUntil(
                formatPenaltyRemaining(profile.requesterPenaltyUntil!),
              );
            } else if (profile.hasActiveWorkerPenalty) {
              penaltySubtitle = SettingsCopy.workerPenaltyUntil(
                formatPenaltyRemaining(profile.workerPenaltyUntil!),
              );
            }
          }

          return SettingsTabScroll(
            children: [
              const TtmSettingsInfoBanner(
                title: SettingsCopy.workerBannerTitle,
                body: SettingsCopy.workerBannerBody,
              ),
              const SizedBox(height: TtmSpacing.xl),
              Text(
                SettingsCopy.workerDistanceTitle,
                style: TtmTypography.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                SettingsCopy.workerDistanceSubtitle,
                style: TtmTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TtmSpacing.md),
              Wrap(
                spacing: TtmSpacing.sm,
                runSpacing: TtmSpacing.sm,
                children: [
                  for (final distance in const [1000, 3000, 5000])
                    _KmChip(
                      label: '${distance ~/ 1000}km',
                      selected: _maxDistanceMeters == distance,
                      onTap: _saving
                          ? null
                          : () => _saveExerciseSettings(
                              maxDistanceMeters: distance,
                              exercises: Set<String>.from(_selectedExercises),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: TtmSpacing.xl),
              Text(
                SettingsCopy.workerTagsTitle,
                style: TtmTypography.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                SettingsCopy.workerTagsSubtitle,
                style: TtmTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TtmSpacing.md),
              Wrap(
                spacing: TtmSpacing.sm,
                runSpacing: TtmSpacing.sm,
                children: [
                  for (final exercise in const [
                    'walking',
                    'running',
                    'badminton',
                    'basketball',
                    'fitness',
                  ])
                    _TagChipSmall(
                      label: exerciseLabel(exercise),
                      selected: _selectedExercises.contains(exercise),
                      onTap: _saving
                          ? null
                          : () {
                              final next = Set<String>.from(_selectedExercises);
                              if (next.contains(exercise)) {
                                if (next.length > 1) next.remove(exercise);
                              } else {
                                next.add(exercise);
                              }
                              _saveExerciseSettings(
                                maxDistanceMeters: _maxDistanceMeters,
                                exercises: next,
                              );
                            },
                    ),
                ],
              ),
              const SizedBox(height: TtmSpacing.xl),
              const TtmSettingsInfoBanner(
                title: SettingsCopy.workerLocationBannerTitle,
                body: SettingsCopy.workerLocationBannerBody,
              ),
              const SizedBox(height: TtmSpacing.xl),
              TtmSettingsGroup(
                children: [
                  TtmSettingsTile(
                    title: SettingsCopy.workerPenaltyTitle,
                    subtitle: penaltySubtitle,
                    showChevron: false,
                    onTap: null,
                  ),
                  TtmSettingsTile(
                    title: SettingsCopy.workerGoHomeTitle,
                    subtitle: SettingsCopy.workerGoHomeSubtitle,
                    onTap: () => context.push(AppRoutes.exercisePreferences),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KmChip extends StatelessWidget {
  const _KmChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filled = isDark ? TtmColors.primaryDark : TtmColors.primary;
    final neutralBg = isDark
        ? TtmColors.darkSurfaceAlt
        : TtmColors.lightSurfaceAlt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TtmRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: TtmSpacing.lg,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? filled : neutralBg,
            borderRadius: BorderRadius.circular(TtmRadius.pill),
          ),
          child: Text(
            label,
            style: TtmTypography.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChipSmall extends StatelessWidget {
  const _TagChipSmall({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      _KmChip(label: label, selected: selected, onTap: onTap);
}

// ── 표시 ─────────────────────────────────────────────────────

class SettingsDisplayTab extends ConsumerStatefulWidget {
  const SettingsDisplayTab({super.key});

  @override
  ConsumerState<SettingsDisplayTab> createState() => _SettingsDisplayTabState();
}

class _SettingsDisplayTabState extends ConsumerState<SettingsDisplayTab> {
  bool _premiumBusy = false;

  Future<void> _setPremiumTest(bool enabled) async {
    if (_premiumBusy) return;
    setState(() => _premiumBusy = true);
    try {
      await ref.read(premiumRepositoryProvider).setPremiumTestMode(enabled);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        _snack(context, enabled ? '프리미엄 모드가 켜졌어요.' : '일반 모드로 바꿨어요.');
      }
    } catch (e) {
      if (mounted) _snack(context, '변경하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _premiumBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin = ref.watch(myAdminRoleProvider).valueOrNull ?? false;
    final isPremium = profile?.isPremium ?? false;

    return SettingsTabScroll(
      children: [
        const TtmSettingsInfoBanner(
          title: SettingsCopy.displayBannerTitle,
          body: SettingsCopy.displayBannerBody,
        ),
        const SizedBox(height: TtmSpacing.xl),
        if (isAdmin) ...[
          const TtmSettingsInfoBanner(
            title: SettingsCopy.premiumTestBannerTitle,
            body: SettingsCopy.premiumTestBannerBody,
          ),
          const SizedBox(height: TtmSpacing.md),
          TtmSettingsGroup(
            children: [
              SwitchListTile(
                title: Text(
                  SettingsCopy.premiumTestTitle,
                  style: TtmTypography.title.copyWith(fontSize: 15),
                ),
                subtitle: Text(
                  isPremium
                      ? SettingsCopy.premiumTestSubtitleOn
                      : SettingsCopy.premiumTestSubtitleOff,
                  style: TtmTypography.body.copyWith(fontSize: 13),
                ),
                value: isPremium,
                onChanged: _premiumBusy ? null : _setPremiumTest,
              ),
            ],
          ),
          const SizedBox(height: TtmSpacing.xl),
        ],
        SettingsChoiceChip(
          label: SettingsCopy.themeSystemTitle,
          subtitle: SettingsCopy.themeSystemSubtitle,
          selected: themeMode == ThemeMode.system,
          onTap: () => ref
              .read(themeModeProvider.notifier)
              .setThemeMode(ThemeMode.system),
        ),
        const SizedBox(height: TtmSpacing.sm),
        SettingsChoiceChip(
          label: SettingsCopy.themeLightTitle,
          subtitle: SettingsCopy.themeLightSubtitle,
          selected: themeMode == ThemeMode.light,
          onTap: () => ref
              .read(themeModeProvider.notifier)
              .setThemeMode(ThemeMode.light),
        ),
        const SizedBox(height: TtmSpacing.sm),
        SettingsChoiceChip(
          label: SettingsCopy.themeDarkTitle,
          subtitle: SettingsCopy.themeDarkSubtitle,
          selected: themeMode == ThemeMode.dark,
          onTap: () =>
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
        ),
      ],
    );
  }
}

// ── 앱 ───────────────────────────────────────────────────────

class SettingsAppTab extends ConsumerWidget {
  const SettingsAppTab({super.key});

  Future<void> _openSupport(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://ttmttm.com/support.html'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      _snack(context, '고객센터를 열지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developerMode = ref.watch(developerModeProvider);

    return SettingsTabScroll(
      children: [
        TtmSettingsGroup(
          children: [
            const TtmSettingsTile(
              title: SettingsCopy.appVersionTitle,
              subtitle: SettingsCopy.appVersion,
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: SettingsCopy.contactTitle,
              subtitle: SettingsCopy.contactSubtitle,
              onTap: () => _openSupport(context),
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xl),
        const TtmSettingsInfoBanner(
          title: SettingsCopy.permissionsBannerTitle,
          body: SettingsCopy.permissionsBannerBody,
        ),
        const SizedBox(height: TtmSpacing.md),
        TtmSettingsGroup(
          children: [
            TtmSettingsTile(
              title: SettingsCopy.permissionsOpenTitle,
              subtitle: SettingsCopy.permissionsOpenSubtitle,
              onTap: () => AppSettings.openAppSettings(),
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xl),
        TtmSettingsGroup(
          sectionTitle: SettingsCopy.developerSectionTitle,
          children: [
            SwitchListTile(
              title: Text(
                SettingsCopy.developerModeTitle,
                style: TtmTypography.title.copyWith(fontSize: 15),
              ),
              subtitle: Text(
                developerMode
                    ? SettingsCopy.developerModeOnSubtitle
                    : SettingsCopy.developerModeOffSubtitle,
                style: TtmTypography.body.copyWith(fontSize: 13),
              ),
              value: developerMode,
              onChanged: (value) =>
                  ref.read(developerModeProvider.notifier).setEnabled(value),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsDeveloperTab extends ConsumerWidget {
  const SettingsDeveloperTab({super.key});

  String _dateLabel(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi:$ss';
  }

  String _sessionExpiryLabel(Session? session) {
    final expiresAt = session?.expiresAt;
    if (expiresAt == null) return '-';
    return _dateLabel(
      DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true),
    );
  }

  String _maskId(String? value) {
    if (value == null || value.isEmpty) return '-';
    if (value.length <= 12) return value;
    return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
  }

  String _prettyJson(Object? value) {
    if (value == null) return '-';
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final session = ref.watch(currentSessionProvider);
    final user = client.auth.currentUser;
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin = ref.watch(myAdminRoleProvider).valueOrNull ?? false;
    final presence = ref.watch(myWorkerPresenceProvider).valueOrNull;
    final colors = Theme.of(context).colorScheme;

    return SettingsTabScroll(
      children: [
        const TtmSettingsInfoBanner(
          title: '개발자 진단',
          body: '앱 동작 확인용 정보입니다. 일반 사용자 화면에는 표시되지 않는 값이 포함돼요.',
          icon: Icons.code_rounded,
        ),
        const SizedBox(height: TtmSpacing.xl),
        TtmSettingsGroup(
          sectionTitle: '앱',
          children: [
            const TtmSettingsTile(
              title: '앱 버전',
              subtitle: SettingsCopy.appVersion,
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: '빌드 모드',
              subtitle: kReleaseMode
                  ? 'release'
                  : (kProfileMode ? 'profile' : 'debug'),
              showChevron: false,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xl),
        TtmSettingsGroup(
          sectionTitle: '백엔드',
          children: [
            TtmSettingsTile(
              title: 'Supabase URL',
              subtitle: Env.supabaseUrl,
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: 'Firebase apps',
              subtitle: Firebase.apps.map((app) => app.name).join(', '),
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: 'Naver Map',
              subtitle: ttmSupportsEmbeddedNaverMap
                  ? 'embedded map supported'
                  : 'fallback preview only',
              showChevron: false,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xl),
        TtmSettingsGroup(
          sectionTitle: '세션',
          children: [
            TtmSettingsTile(
              title: 'Auth user id',
              subtitle: _maskId(user?.id),
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: 'Email',
              subtitle: user?.email ?? '-',
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: 'Session expires',
              subtitle: _sessionExpiryLabel(session),
              showChevron: false,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xl),
        TtmSettingsGroup(
          sectionTitle: '프로필',
          children: [
            TtmSettingsTile(
              title: 'Nickname',
              subtitle: profile?.nickname ?? '-',
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: 'Premium',
              subtitle: '${profile?.isPremium ?? false}',
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: 'Requester penalty',
              subtitle: _dateLabel(profile?.requesterPenaltyUntil),
              showChevron: false,
              onTap: null,
            ),
            TtmSettingsTile(
              title: 'Worker penalty',
              subtitle: _dateLabel(profile?.workerPenaltyUntil),
              showChevron: false,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: TtmSpacing.xl),
        TtmSettingsGroup(
          sectionTitle: '작업자 상태',
          children: [
            Padding(
              padding: const EdgeInsets.all(TtmSpacing.lg),
              child: SelectableText(
                _prettyJson(presence),
                style: TtmTypography.body.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: TtmSpacing.xl),
          const _AdminReportsPanel(),
        ],
      ],
    );
  }
}

class _AdminReportsPanel extends ConsumerWidget {
  const _AdminReportsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userReports = ref.watch(adminUserReportsProvider);
    final messageReports = ref.watch(adminMessageReportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TtmSettingsInfoBanner(
          title: '관리자 신고 확인',
          body: '접수된 사용자 신고와 메세지 신고를 최신순으로 확인하고 상태를 바꿀 수 있어요.',
          icon: Icons.admin_panel_settings_rounded,
        ),
        const SizedBox(height: TtmSpacing.md),
        _AdminReportList(
          title: '사용자 신고',
          asyncRows: userReports,
          onRefresh: () => ref.invalidate(adminUserReportsProvider),
          onStatus: (id, status) async {
            await ref
                .read(reportRepositoryProvider)
                .updateUserReportStatus(reportId: id, status: status);
            ref.invalidate(adminUserReportsProvider);
          },
        ),
        const SizedBox(height: TtmSpacing.xl),
        _AdminReportList(
          title: '메세지 신고',
          asyncRows: messageReports,
          onRefresh: () => ref.invalidate(adminMessageReportsProvider),
          onStatus: (id, status) async {
            await ref
                .read(reportRepositoryProvider)
                .updateMessageReportStatus(reportId: id, status: status);
            ref.invalidate(adminMessageReportsProvider);
          },
        ),
      ],
    );
  }
}

class _AdminReportList extends StatelessWidget {
  const _AdminReportList({
    required this.title,
    required this.asyncRows,
    required this.onRefresh,
    required this.onStatus,
  });

  final String title;
  final AsyncValue<List<Map<String, dynamic>>> asyncRows;
  final VoidCallback onRefresh;
  final Future<void> Function(String id, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    return asyncRows.when(
      loading: () => TtmSettingsGroup(
        sectionTitle: title,
        children: const [
          Padding(
            padding: EdgeInsets.all(TtmSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => TtmSettingsGroup(
        sectionTitle: title,
        children: [
          TtmSettingsTile(
            title: '불러오지 못했어요',
            subtitle: '$error',
            onTap: onRefresh,
          ),
        ],
      ),
      data: (rows) => TtmSettingsGroup(
        sectionTitle: '$title (${rows.length})',
        children: rows.isEmpty
            ? [
                const TtmSettingsTile(
                  title: '접수된 신고 없음',
                  subtitle: '새 신고가 접수되면 여기에 표시돼요.',
                  showChevron: false,
                  onTap: null,
                ),
              ]
            : [
                for (final row in rows.take(20))
                  _AdminReportTile(row: row, onStatus: onStatus),
              ],
      ),
    );
  }
}

class _AdminReportTile extends StatelessWidget {
  const _AdminReportTile({required this.row, required this.onStatus});

  final Map<String, dynamic> row;
  final Future<void> Function(String id, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final id = row['id']?.toString() ?? '';
    final status = row['status']?.toString() ?? 'open';
    final category = row['category']?.toString() ?? '-';
    final createdAt = row['created_at']?.toString() ?? '-';
    final description = row['description']?.toString();
    final snapshot = row['message_snapshot']?.toString();
    final target = row['reported_user_id']?.toString() ?? '-';
    final request = row['request_id']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TtmSpacing.lg,
        vertical: TtmSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$category · $status',
            style: TtmTypography.title.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            [
              '대상: $target',
              if (request != null) '요청: $request',
              '접수: $createdAt',
              if (snapshot != null) '메세지: $snapshot',
              if (description != null && description.isNotEmpty)
                '설명: $description',
            ].join('\n'),
            style: TtmTypography.body.copyWith(fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: TtmSpacing.sm),
          Wrap(
            spacing: TtmSpacing.sm,
            runSpacing: TtmSpacing.sm,
            children: [
              _ReportStatusButton(
                label: '검토 중',
                selected: status == 'reviewing',
                onTap: id.isEmpty ? null : () => onStatus(id, 'reviewing'),
              ),
              _ReportStatusButton(
                label: '처리 완료',
                selected: status == 'resolved',
                onTap: id.isEmpty ? null : () => onStatus(id, 'resolved'),
              ),
              _ReportStatusButton(
                label: '기각',
                selected: status == 'rejected',
                onTap: id.isEmpty ? null : () => onStatus(id, 'rejected'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStatusButton extends StatelessWidget {
  const _ReportStatusButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: selected ? const Icon(Icons.check_rounded, size: 16) : null,
      onPressed: onTap,
    );
  }
}
