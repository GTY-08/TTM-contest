import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../match/widgets/radius_pulse.dart';
import '../../match/widgets/stage_progress_bar.dart';
import '../models/exercise_matching_models.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';
import '../services/exercise_location_service.dart';

class ExerciseQuickMatchScreen extends ConsumerStatefulWidget {
  const ExerciseQuickMatchScreen({super.key});

  @override
  ConsumerState<ExerciseQuickMatchScreen> createState() =>
      _ExerciseQuickMatchScreenState();
}

class _ExerciseQuickMatchScreenState
    extends ConsumerState<ExerciseQuickMatchScreen> {
  Timer? _timer;
  bool _busy = false;
  bool _polling = false;
  String _meetingSource = 'current';
  String? _venueId;
  String _exercise = 'walking';
  int _duration = 30;
  bool _directDuration = false;
  final _durationController = TextEditingController(text: '45');
  String _intensity = 'medium';
  String _partnerLevel = 'similar';
  int _distance = 3000;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(myQuickMatchProvider);
    final offers = ref.watch(exerciseMatchOffersProvider);
    final preferences = ref.watch(exercisePreferencesProvider);
    final venues = ref.watch(exerciseVenuesProvider);
    final presence = ref.watch(myWorkerPresenceProvider).valueOrNull;
    final presenceStatus = presence?['status']?.toString();
    final online = presenceStatus == 'online' || presenceStatus == 'busy';
    final activeMatch = current.valueOrNull;
    return PopScope(
      canPop: activeMatch?.isSearching != true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('지금 운동 매칭'),
          actions: [
            if (activeMatch == null)
              IconButton(
                tooltip: '운동 설정',
                onPressed: () => context.push(AppRoutes.exercisePreferences),
                icon: const Icon(Icons.tune_rounded),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.md,
              TtmSpacing.lg,
              60,
            ),
            children: [
              current.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (match) => match == null
                    ? const SizedBox.shrink()
                    : _CurrentMatchCard(
                        match: match,
                        busy: _busy,
                        onCancel: () => _cancel(match.id),
                        onComplete: () => _complete(match.id),
                        onChat: () => context.push(
                          '${AppRoutes.quickMatch}/${match.id}/chat',
                        ),
                      ),
              ),
              if (activeMatch == null) ...[
                const SizedBox(height: TtmSpacing.md),
                offers.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '도착한 운동 제안',
                              style: TtmTypography.title.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: TtmSpacing.sm),
                            for (final offer in items) ...[
                              _OfferCard(
                                offer: offer,
                                busy: _busy,
                                onAccept: () => _respondOffer(offer.id, true),
                                onDecline: () => _respondOffer(offer.id, false),
                              ),
                              const SizedBox(height: TtmSpacing.sm),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: TtmSpacing.md),
                preferences.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Text('운동 설정을 불러오지 못했어요.'),
                  data: (prefs) => _AvailabilityCard(
                    online: online,
                    busy: _busy,
                    onChanged: (value) => _setAvailability(value, prefs),
                  ),
                ),
                const SizedBox(height: TtmSpacing.lg),
                _buildForm(venues),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AsyncValue<List<ExerciseVenue>> venues) {
    final venueItems = venues.valueOrNull ?? const <ExerciseVenue>[];
    if (_venueId == null && venueItems.isNotEmpty) {
      _venueId = venueItems.first.id;
    }
    final duration = _directDuration
        ? int.tryParse(_durationController.text) ?? 45
        : _duration;
    return TtmTierCard(
      tier: TtmCardTier.feed,
      padding: const EdgeInsets.all(TtmSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '어떤 운동을 함께할까요?',
            style: TtmTypography.display.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 6),
          Text('조건이 맞는 가까운 한 명과 바로 연결해요.', style: TtmTypography.body),
          const SizedBox(height: TtmSpacing.lg),
          _label('만날 곳'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'current', label: Text('현재 위치')),
              ButtonSegment(value: 'venue', label: Text('운동 장소')),
            ],
            selected: {_meetingSource},
            onSelectionChanged: (value) =>
                setState(() => _meetingSource = value.first),
            showSelectedIcon: false,
          ),
          if (_meetingSource == 'venue') ...[
            const SizedBox(height: TtmSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _venueId,
              decoration: const InputDecoration(labelText: '등록된 운동 장소'),
              items: venueItems
                  .map(
                    (venue) => DropdownMenuItem(
                      value: venue.id,
                      child: Text(venue.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _venueId = value),
            ),
          ],
          const SizedBox(height: TtmSpacing.md),
          _label('운동 종목'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _exerciseOptions.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: _exercise == entry.key,
                    onSelected: (_) => setState(() => _exercise = entry.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: TtmSpacing.md),
          _label('운동 시간'),
          Wrap(
            spacing: 6,
            children: [
              for (final value in const [30, 60, 90])
                ChoiceChip(
                  label: Text('$value분'),
                  selected: !_directDuration && _duration == value,
                  onSelected: (_) => setState(() {
                    _directDuration = false;
                    _duration = value;
                  }),
                ),
              ChoiceChip(
                label: const Text('직접 입력'),
                selected: _directDuration,
                onSelected: (_) => setState(() => _directDuration = true),
              ),
            ],
          ),
          if (_directDuration) ...[
            const SizedBox(height: TtmSpacing.sm),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '운동 시간',
                suffixText: '분',
                helperText: '20분부터 240분까지 입력할 수 있어요.',
              ),
            ),
          ],
          const SizedBox(height: TtmSpacing.md),
          _label('강도'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'low', label: Text('가볍게')),
              ButtonSegment(value: 'medium', label: Text('보통')),
              ButtonSegment(value: 'high', label: Text('강하게')),
            ],
            selected: {_intensity},
            onSelectionChanged: (value) =>
                setState(() => _intensity = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: TtmSpacing.md),
          _label('파트너 수준'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'similar', label: Text('비슷하게')),
              ButtonSegment(value: 'beginner', label: Text('초보자')),
              ButtonSegment(value: 'any', label: Text('상관없음')),
            ],
            selected: {_partnerLevel},
            onSelectionChanged: (value) =>
                setState(() => _partnerLevel = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: TtmSpacing.md),
          _label('찾을 거리'),
          Wrap(
            spacing: 6,
            children: [
              for (final value in const [1000, 3000, 5000])
                ChoiceChip(
                  label: Text('${value ~/ 1000}km'),
                  selected: _distance == value,
                  onSelected: (_) => setState(() => _distance = value),
                ),
            ],
          ),
          const SizedBox(height: TtmSpacing.lg),
          TTMButton(
            label: '운동 파트너 찾기',
            icon: Icons.flash_on_rounded,
            busy: _busy,
            onPressed: _busy || duration < 20 || duration > 240
                ? null
                : () => _create(duration, venueItems),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: TtmTypography.label),
  );

  Future<void> _setAvailability(bool value, ExercisePreferences prefs) async {
    ExerciseLocationSnapshot? location;
    if (value) {
      try {
        location = await ref.read(exerciseLocationServiceProvider).current();
      } on ExerciseLocationException catch (error) {
        _show(exerciseLocationMessage(error.reason));
        return;
      }
    }
    await _run(
      () => ref
          .read(raidRepositoryProvider)
          .setExerciseAvailability(
            online: value,
            location: location,
            maxDistanceMeters: prefs.maxDistanceMeters,
            exerciseTypes: prefs.preferredExercises,
          ),
    );
    ref.invalidate(myWorkerPresenceProvider);
  }

  Future<void> _create(int duration, List<ExerciseVenue> venues) async {
    if (_meetingSource == 'venue' && _venueId == null) {
      _show('운동 장소를 선택해 주세요.');
      return;
    }
    try {
      final location = await ref
          .read(exerciseLocationServiceProvider)
          .current();
      ExerciseVenue? venue;
      if (_meetingSource == 'venue') {
        for (final item in venues) {
          if (item.id == _venueId) {
            venue = item;
            break;
          }
        }
      }
      await _run(
        () => ref
            .read(raidRepositoryProvider)
            .createQuickMatch(
              meetingSource: _meetingSource,
              venueId: _meetingSource == 'venue' ? _venueId : null,
              meetingLabel: venue?.name ?? '현재 위치 근처',
              exerciseType: _exercise,
              durationMinutes: duration,
              intensity: _intensity,
              partnerLevelPreference: _partnerLevel,
              maxDistanceMeters: _distance,
              location: location,
            ),
      );
    } on ExerciseLocationException catch (error) {
      _show(exerciseLocationMessage(error.reason));
    }
  }

  Future<void> _respondOffer(String offerId, bool accept) async {
    ExerciseLocationSnapshot? location;
    if (accept) {
      try {
        location = await ref.read(exerciseLocationServiceProvider).current();
      } on ExerciseLocationException catch (error) {
        _show(exerciseLocationMessage(error.reason));
        return;
      }
    }
    await _run(
      () => ref
          .read(raidRepositoryProvider)
          .respondQuickMatchOffer(
            offerId: offerId,
            accept: accept,
            location: location,
          ),
    );
  }

  Future<void> _cancel(String id) =>
      _run(() => ref.read(raidRepositoryProvider).cancelQuickMatch(id));

  Future<void> _complete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('1대1 운동을 완료할까요?'),
        content: const Text('완료하면 두 참여자 모두 활동 포인트 100P를 받아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('완료하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .completeQuickMatch(id);
      if (!mounted) return;
      if (result['ok'] == true) {
        ref.invalidate(rewardSummaryProvider);
        ref.invalidate(exerciseActivitySummaryProvider);
        _show(
          result['already_completed'] == true
              ? '이미 완료된 운동이에요.'
              : '운동 완료! 두 사람 모두 100P를 받았어요.',
        );
      } else {
        _show(exerciseLocationMessage(result['reason']?.toString() ?? ''));
      }
      await _refresh();
    } catch (_) {
      if (mounted) _show('완료하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tick() async {
    if (!mounted || _busy || _polling) return;
    _polling = true;
    try {
      final match = ref.read(myQuickMatchProvider).valueOrNull;
      if (match?.isSearching == true &&
          match?.requesterId == ref.read(authUserIdProvider)) {
        await ref.read(raidRepositoryProvider).advanceQuickMatch(match!.id);
      }
      if (mounted) await _refresh();
    } finally {
      _polling = false;
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      if (result['ok'] != true) {
        _show(exerciseLocationMessage(result['reason']?.toString() ?? ''));
      }
      await _refresh();
    } catch (_) {
      if (mounted) _show('처리하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(myQuickMatchProvider);
    ref.invalidate(exerciseMatchOffersProvider);
    await Future.wait([
      ref.read(myQuickMatchProvider.future),
      ref.read(exerciseMatchOffersProvider.future),
    ]);
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.online,
    required this.busy,
    required this.onChanged,
  });
  final bool online;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => TtmTierCard(
    tier: TtmCardTier.status,
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('운동 제안 받기'),
      subtitle: const Text('30분 동안 가까운 운동 제안을 받을 수 있어요.'),
      value: online,
      onChanged: busy ? null : onChanged,
    ),
  );
}

class _CurrentMatchCard extends StatelessWidget {
  const _CurrentMatchCard({
    required this.match,
    required this.busy,
    required this.onCancel,
    required this.onComplete,
    required this.onChat,
  });
  final ExerciseQuickMatch match;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TtmTierCard(
      tier: TtmCardTier.mission,
      padding: const EdgeInsets.all(TtmSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            match.isSearching ? '운동 파트너를 찾고 있어요' : '1:1 운동 매칭이 확정됐어요',
            textAlign: TextAlign.center,
            style: TtmTypography.display.copyWith(
              color: colors.onSurface,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${exerciseLabel(match.exerciseType)} · ${match.meetingLabel} · ${match.durationMinutes}분',
            textAlign: TextAlign.center,
            style: TtmTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: TtmSpacing.lg),
          if (match.isSearching) ...[
            StageProgressBar(currentStage: match.currentStage),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              '단계 ${match.currentStage}/10 · 가까운 사람부터 범위를 넓히고 있어요',
              textAlign: TextAlign.center,
              style: TtmTypography.label.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TtmSpacing.sm),
            const Center(child: RadiusPulse(size: 170)),
          ] else ...[
            FilledButton.icon(
              onPressed: busy ? null : onChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('1:1 채팅 열기'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: busy ? null : onComplete,
              child: const Text('운동 완료'),
            ),
          ],
          TextButton(
            onPressed: busy ? null : onCancel,
            child: const Text('매칭 취소'),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });
  final ExerciseMatchOffer offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => TtmTierCard(
    tier: TtmCardTier.feed,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${offer.requester?['nickname'] ?? '운동 파트너'}님의 제안',
          style: TtmTypography.title,
        ),
        const SizedBox(height: 5),
        Text(
          '${exerciseLabel(offer.exerciseType)} · ${offer.meetingLabel}\n${offer.durationMinutes}분 · ${(offer.distanceMeters / 1000).toStringAsFixed(1)}km',
        ),
        const SizedBox(height: TtmSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onDecline,
                child: const Text('거절'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onAccept,
                child: const Text('함께 운동'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

const _exerciseOptions = <String, String>{
  'walking': '걷기',
  'running': '러닝',
  'badminton': '배드민턴',
  'basketball': '농구',
  'fitness': '기초 체력',
};
