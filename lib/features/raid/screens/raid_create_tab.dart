import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/home_navigation_provider.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../premium/screens/premium_screen.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';

class RaidCreateTab extends ConsumerStatefulWidget {
  const RaidCreateTab({super.key});

  @override
  ConsumerState<RaidCreateTab> createState() => _RaidCreateTabState();
}

class _RaidCreateTabState extends ConsumerState<RaidCreateTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _feeController = TextEditingController(text: '0');
  String? _venueId;
  String? _exerciseType;
  String _intensity = 'medium';
  DateTime _startsAt = DateTime.now().add(const Duration(days: 1, hours: 1));
  int _duration = 60;
  int _minParticipants = 3;
  int _maxParticipants = 10;
  bool _beginnerFriendly = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium =
        ref.watch(myProfileProvider).valueOrNull?.isPremium ?? false;
    final venuesAsync = ref.watch(exerciseVenuesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        TtmSpacing.md,
        TtmSpacing.lg,
        120,
      ),
      children: [
        Text('운동 레이드 만들기', style: TtmTypography.display.copyWith(fontSize: 24)),
        const SizedBox(height: TtmSpacing.xs),
        Text(
          '장소와 일정을 정하고 함께 운동할 사람을 모집해 보세요.',
          style: TtmTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TtmSpacing.lg),
        if (!isPremium)
          _PremiumGate(
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
            ),
          )
        else
          venuesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('운동 장소를 불러오지 못했어요.'),
            data: (venues) => _buildForm(venues),
          ),
      ],
    );
  }

  Widget _buildForm(List<ExerciseVenue> venues) {
    final venue = venues.where((item) => item.id == _venueId).firstOrNull;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: '운동 장소',
            child: DropdownButtonFormField<String>(
              initialValue: _venueId,
              decoration: const InputDecoration(
                hintText: '등록된 운동 장소를 선택해 주세요',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              items: [
                for (final item in venues)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              validator: (value) => value == null ? '운동 장소를 선택해 주세요.' : null,
              onChanged: (value) {
                final selected = venues
                    .where((item) => item.id == value)
                    .firstOrNull;
                setState(() {
                  _venueId = value;
                  _exerciseType = selected?.supportedExercises.firstOrNull;
                  _duration = selected?.defaultDurationMinutes ?? _duration;
                  _minParticipants = selected?.recommendedMinParticipants ?? 3;
                  _maxParticipants = selected?.maxParticipants ?? 10;
                  _intensity = selected?.defaultIntensity ?? 'medium';
                  _beginnerFriendly = selected?.beginnerFriendly ?? true;
                });
              },
            ),
          ),
          if (venue != null) ...[
            const SizedBox(height: TtmSpacing.md),
            _Section(
              title: '운동 종목',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in venue.supportedExercises)
                    ChoiceChip(
                      label: Text(exerciseLabel(type)),
                      selected: _exerciseType == type,
                      onSelected: (_) => setState(() => _exerciseType = type),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: TtmSpacing.md),
          _Section(
            title: '레이드 소개',
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '예: 퇴근 후 초보 러닝',
                  ),
                  maxLength: 100,
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? '제목을 2자 이상 입력해 주세요.'
                      : null,
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '안내',
                    hintText: '준비물과 진행 방식을 알려주세요.',
                  ),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          _Section(
            title: '일정',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('시작 시간'),
                  subtitle: Text(
                    DateFormat('yyyy년 M월 d일 (E) HH:mm', 'ko').format(_startsAt),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickDateTime,
                ),
                DropdownButtonFormField<int>(
                  initialValue: _duration,
                  decoration: const InputDecoration(labelText: '운동 시간'),
                  items: const [30, 40, 50, 60, 90, 120]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value분'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _duration = value ?? 60),
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          _Section(
            title: '참가 조건',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _NumberPicker(
                        label: '최소 인원',
                        value: _minParticipants,
                        min: 3,
                        max: _maxParticipants,
                        onChanged: (v) => setState(() => _minParticipants = v),
                      ),
                    ),
                    const SizedBox(width: TtmSpacing.sm),
                    Expanded(
                      child: _NumberPicker(
                        label: '최대 인원',
                        value: _maxParticipants,
                        min: _minParticipants,
                        max: venue?.maxParticipants ?? 30,
                        onChanged: (v) => setState(() => _maxParticipants = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TtmSpacing.md),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('가볍게')),
                    ButtonSegment(value: 'medium', label: Text('보통')),
                    ButtonSegment(value: 'high', label: Text('높음')),
                  ],
                  selected: {_intensity},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _intensity = value.first),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('초보자도 참가할 수 있어요'),
                  value: _beginnerFriendly,
                  onChanged: (value) =>
                      setState(() => _beginnerFriendly = value),
                ),
                TextFormField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '참가비',
                    suffixText: '원',
                    helperText: '0원으로 설정하면 무료로 모집해요.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.lg),
          TTMButton(
            label: '레이드 모집 시작',
            busy: _saving,
            onPressed: _saving ? null : _submit,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _venueId == null ||
        _exerciseType == null) {
      return;
    }
    if (_startsAt.isBefore(DateTime.now().add(const Duration(minutes: 10)))) {
      _show('시작 시간은 지금부터 10분 이후로 설정해 주세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .createPremiumRaid(
            venueId: _venueId!,
            exerciseType: _exerciseType!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            startsAt: _startsAt,
            durationMinutes: _duration,
            minParticipants: _minParticipants,
            maxParticipants: _maxParticipants,
            intensity: _intensity,
            beginnerFriendly: _beginnerFriendly,
            participationFee: int.tryParse(_feeController.text) ?? 0,
          );
      if (!mounted) return;
      if (result['ok'] == true) {
        ref.invalidate(nearbyRaidsProvider);
        ref.invalidate(myRaidsProvider);
        ref.read(homeTabIndexProvider.notifier).state = 3;
        _show('레이드 모집을 시작했어요.');
      } else {
        _show(_reasonMessage(result['reason']?.toString()));
      }
    } catch (error) {
      if (mounted) _show(_reasonMessage(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _reasonMessage(String? reason) {
    final value = reason ?? '';
    if (value.contains('premium_required')) return '프리미엄 이용자만 레이드를 만들 수 있어요.';
    if (value.contains('start_time_too_soon')) {
      return '시작 시간을 조금 더 여유 있게 설정해 주세요.';
    }
    if (value.contains('exercise_not_supported')) {
      return '이 장소에서 지원하지 않는 운동이에요.';
    }
    return '레이드를 만들지 못했어요. 입력 내용을 확인해 주세요.';
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class _PremiumGate extends StatelessWidget {
  const _PremiumGate({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => TtmTierCard(
    tier: TtmCardTier.mission,
    padding: const EdgeInsets.all(TtmSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.workspace_premium_rounded,
          color: Colors.white,
          size: 36,
        ),
        const SizedBox(height: TtmSpacing.md),
        Text(
          '내 운동 레이드를 운영해 보세요',
          style: TtmTypography.title.copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: TtmSpacing.xs),
        Text(
          '프리미엄 이용자는 일정과 참가 조건을 정하고 참가자를 직접 승인할 수 있어요.',
          style: TtmTypography.body.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: TtmSpacing.lg),
        TTMButton(
          label: '프리미엄 혜택 보기',
          onPressed: onOpen,
          variant: TtmButtonVariant.secondary,
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => TtmTierCard(
    tier: TtmCardTier.feed,
    padding: const EdgeInsets.all(TtmSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: TtmTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: TtmSpacing.md),
        child,
      ],
    ),
  );
}

class _NumberPicker extends StatelessWidget {
  const _NumberPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TtmTypography.label),
      const SizedBox(height: 6),
      Row(
        children: [
          IconButton.filledTonal(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              '$value명',
              textAlign: TextAlign.center,
              style: TtmTypography.metric,
            ),
          ),
          IconButton.filledTonal(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    ],
  );
}
