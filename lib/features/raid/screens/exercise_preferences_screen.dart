import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../models/exercise_matching_models.dart';
import '../providers/raid_providers.dart';
import '../services/exercise_location_service.dart';

class ExercisePreferencesScreen extends ConsumerStatefulWidget {
  const ExercisePreferencesScreen({super.key});

  @override
  ConsumerState<ExercisePreferencesScreen> createState() =>
      _ExercisePreferencesScreenState();
}

class _ExercisePreferencesScreenState
    extends ConsumerState<ExercisePreferencesScreen> {
  bool _initialized = false;
  bool _busy = false;
  final Set<String> _exercises = {'walking'};
  final Set<int> _days = {1, 2, 3, 4, 5, 6, 7};
  String _fitnessLevel = 'beginner';
  TimeOfDay _start = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 22, minute: 0);
  int _distance = 5000;
  String? _activityLabel;
  double? _latitude;
  double? _longitude;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(exercisePreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('운동 설정')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('운동 설정을 불러오지 못했어요.')),
        data: (value) {
          _initialize(value);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.md,
              TtmSpacing.lg,
              60,
            ),
            children: [
              Text(
                '나에게 맞는 운동을 추천받아요',
                style: TtmTypography.display.copyWith(fontSize: 23),
              ),
              const SizedBox(height: 6),
              Text(
                '활동 지역과 가능한 시간을 기준으로 레이드와 빠른 매칭을 찾아요.',
                style: TtmTypography.body,
              ),
              const SizedBox(height: TtmSpacing.xl),
              _section('활동 지역'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location_rounded),
                title: Text(_activityLabel ?? '아직 설정하지 않았어요'),
                subtitle: const Text('정확한 좌표는 주변 추천 계산에만 사용해요.'),
                trailing: OutlinedButton(
                  onPressed: _busy ? null : _setCurrentArea,
                  child: const Text('현재 위치'),
                ),
              ),
              const SizedBox(height: TtmSpacing.lg),
              _section('선호 운동'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _exerciseOptions.entries
                    .map(
                      (entry) => FilterChip(
                        label: Text(entry.value),
                        selected: _exercises.contains(entry.key),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _exercises.add(entry.key);
                          } else if (_exercises.length > 1) {
                            _exercises.remove(entry.key);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: TtmSpacing.lg),
              _section('운동 수준'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'beginner', label: Text('입문')),
                  ButtonSegment(value: 'intermediate', label: Text('중간')),
                  ButtonSegment(value: 'advanced', label: Text('숙련')),
                ],
                selected: {_fitnessLevel},
                onSelectionChanged: (value) =>
                    setState(() => _fitnessLevel = value.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: TtmSpacing.lg),
              _section('가능한 요일'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const ['월', '화', '수', '목', '금', '토', '일']
                    .asMap()
                    .entries
                    .map(
                      (entry) => FilterChip(
                        label: Text(entry.value),
                        selected: _days.contains(entry.key + 1),
                        onSelected: (selected) => setState(() {
                          final day = entry.key + 1;
                          if (selected) {
                            _days.add(day);
                          } else if (_days.length > 1) {
                            _days.remove(day);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: TtmSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(true),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text('시작 ${_start.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(false),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text('종료 ${_end.format(context)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TtmSpacing.lg),
              _section('최대 이동 거리'),
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
              const SizedBox(height: TtmSpacing.xl),
              TTMButton(
                label: '운동 설정 저장',
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TtmTypography.title.copyWith(fontSize: 17)),
  );

  void _initialize(ExercisePreferences value) {
    if (_initialized) return;
    _initialized = true;
    _exercises
      ..clear()
      ..addAll(
        value.preferredExercises.isEmpty
            ? const ['walking']
            : value.preferredExercises,
      );
    _days
      ..clear()
      ..addAll(
        value.availableDays.isEmpty
            ? const [1, 2, 3, 4, 5, 6, 7]
            : value.availableDays,
      );
    _fitnessLevel = value.fitnessLevel;
    _start = _parseTime(
      value.availableStart,
      const TimeOfDay(hour: 6, minute: 0),
    );
    _end = _parseTime(value.availableEnd, const TimeOfDay(hour: 22, minute: 0));
    _distance = value.maxDistanceMeters;
    _activityLabel = value.activityLabel;
    _latitude = value.latitude;
    _longitude = value.longitude;
  }

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  Future<void> _pickTime(bool start) async {
    final value = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _setCurrentArea() async {
    try {
      final location = await ref
          .read(exerciseLocationServiceProvider)
          .current();
      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _activityLabel = '현재 위치 주변';
      });
    } on ExerciseLocationException catch (error) {
      _show(exerciseLocationMessage(error.reason));
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .saveExercisePreferences(
            activityLabel: _activityLabel,
            latitude: _latitude,
            longitude: _longitude,
            exercises: _exercises.toList(),
            fitnessLevel: _fitnessLevel,
            availableDays: _days.toList()..sort(),
            availableStart: _sqlTime(_start),
            availableEnd: _sqlTime(_end),
            maxDistanceMeters: _distance,
          );
      if (!mounted) return;
      if (result['ok'] == true) {
        ref.invalidate(exercisePreferencesProvider);
        _show('운동 설정을 저장했어요.');
      } else {
        _show('운동 설정을 저장하지 못했어요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _sqlTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

const _exerciseOptions = <String, String>{
  'walking': '걷기',
  'running': '러닝',
  'badminton': '배드민턴',
  'basketball': '농구',
  'fitness': '기초 체력',
};
