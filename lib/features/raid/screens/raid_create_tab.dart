import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/ttm_card_tier.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/home_navigation_provider.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../../../shared/widgets/ttm_tier_card.dart';
import '../../match/widgets/meet_point_map_picker.dart';
import '../../premium/screens/premium_screen.dart';
import '../models/raid_models.dart';
import '../providers/raid_providers.dart';
import '../services/exercise_location_service.dart';

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
  final _placeSearchController = TextEditingController();
  final _mapKey = GlobalKey<MeetPointMapPickerState>();
  NLatLng _mapCenter = const NLatLng(37.5665, 126.9780);
  double? _locationLatitude;
  double? _locationLongitude;
  String? _locationLabel;
  String? _locationAddress;
  bool _preserveLocationLabelOnNextMapUpdate = false;
  bool _locationBusy = false;
  bool _placeSearchBusy = false;
  String? _exerciseType;
  String _intensity = 'medium';
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 1));
  int _duration = 60;
  int _minParticipants = 3;
  int _maxParticipants = 10;
  bool _beginnerFriendly = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_useCurrentLocation(showMessage: false));
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    _placeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium =
        ref.watch(myProfileProvider).valueOrNull?.isPremium ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.lg,
        TtmSpacing.md,
        TtmSpacing.lg,
        120,
      ),
      children: [
        Text('일반 매칭 만들기', style: TtmTypography.display.copyWith(fontSize: 24)),
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
          _buildForm(),
      ],
    );
  }

  Widget _buildForm() {
    final colors = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: '운동 장소',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MeetPointMapPicker(
                  key: _mapKey,
                  initialCenter: _mapCenter,
                  height: 250,
                  onPickChanged: _onMapPickChanged,
                ),
                const SizedBox(height: TtmSpacing.md),
                TextField(
                  controller: _placeSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchPlace(),
                  decoration: InputDecoration(
                    hintText: '주소나 장소 검색',
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: _placeSearchBusy
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: '검색',
                            onPressed: _searchPlace,
                            icon: const Icon(Icons.search_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: TtmSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedLocationText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.label.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _locationBusy
                          ? null
                          : () => _useCurrentLocation(showMessage: true),
                      icon: _locationBusy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: const Text('내 위치'),
                    ),
                  ],
                ),
                Text(
                  '지도를 움직여 중앙 핀으로 만날 위치를 직접 정할 수 있어요.',
                  style: TtmTypography.label.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.md),
          _Section(
            title: '운동 종목',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in const [
                  'walking',
                  'running',
                  'badminton',
                  'basketball',
                  'fitness',
                ])
                  ChoiceChip(
                    label: Text(exerciseLabel(type)),
                    selected: _exerciseType == type,
                    onSelected: (_) => setState(() => _exerciseType = type),
                  ),
              ],
            ),
          ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '레이드는 현재부터 6시간 이내에 시작할 수 있어요.',
                    style: TtmTypography.label.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: TtmSpacing.sm),
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
                        max: 30,
                        onChanged: (v) => setState(() => _maxParticipants = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TtmSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const {
                      'low': '가볍게',
                      'medium': '보통',
                      'high': '높음',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _intensity == entry.key,
                        onSelected: (_) =>
                            setState(() => _intensity = entry.key),
                      ),
                  ],
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
                    helperText: '참가비가 없다면 0원으로 입력해 주세요.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TtmSpacing.lg),
          TTMButton(
            label: '일반 매칭 모집 시작',
            busy: _saving,
            onPressed: _saving ? null : _submit,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }

  String get _selectedLocationText {
    final label = _locationLabel;
    if (label != null && label.isNotEmpty) {
      final address = _locationAddress;
      return address == null || address.isEmpty ? label : '$label\n$address';
    }
    final latitude = _locationLatitude;
    final longitude = _locationLongitude;
    if (latitude != null && longitude != null) {
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }
    return '지도를 움직이거나 장소를 검색해 주세요.';
  }

  void _onMapPickChanged(double latitude, double longitude) {
    final preserve = _preserveLocationLabelOnNextMapUpdate;
    setState(() {
      _locationLatitude = latitude;
      _locationLongitude = longitude;
      if (!preserve) {
        _locationLabel = null;
        _locationAddress = null;
      }
      _preserveLocationLabelOnNextMapUpdate = false;
    });
  }

  Future<void> _useCurrentLocation({required bool showMessage}) async {
    if (_locationBusy) return;
    setState(() => _locationBusy = true);
    try {
      final location = await ref
          .read(exerciseLocationServiceProvider)
          .current();
      if (!mounted) return;
      final point = NLatLng(location.latitude, location.longitude);
      setState(() {
        _mapCenter = point;
        _locationLatitude = location.latitude;
        _locationLongitude = location.longitude;
        _locationLabel = '내 위치 근처';
        _locationAddress = null;
        _preserveLocationLabelOnNextMapUpdate = true;
      });
      await _mapKey.currentState?.moveTo(point, zoom: 17);
      if (showMessage && mounted) _show('현재 위치로 지도를 이동했어요.');
    } on ExerciseLocationException catch (error) {
      if (showMessage && mounted) {
        _show(exerciseLocationMessage(error.reason));
      }
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _searchPlace() async {
    final query = _placeSearchController.text.trim();
    if (query.length < 2) {
      _show('검색어를 두 글자 이상 입력해 주세요.');
      return;
    }
    if (_placeSearchBusy) return;
    setState(() => _placeSearchBusy = true);
    try {
      final results = await ref
          .read(raidRepositoryProvider)
          .searchPlaces(query);
      if (!mounted) return;
      if (results.isEmpty) {
        _show('검색 결과가 없어요. 다른 단어로 찾아보세요.');
        return;
      }
      final sorted = [...results]
        ..sort(
          (a, b) =>
              _distanceFromMapCenter(a).compareTo(_distanceFromMapCenter(b)),
        );
      final selected = sorted.length == 1
          ? sorted.first
          : await _showPlaceResults(sorted);
      if (selected == null || !mounted) return;
      final point = NLatLng(selected.latitude, selected.longitude);
      setState(() {
        _mapCenter = point;
        _locationLatitude = selected.latitude;
        _locationLongitude = selected.longitude;
        _locationLabel = selected.label;
        _locationAddress = selected.address;
        _preserveLocationLabelOnNextMapUpdate = true;
      });
      await _mapKey.currentState?.moveTo(point, zoom: 17);
      if (mounted) _show('${selected.label}(으)로 지도를 이동했어요.');
    } catch (_) {
      if (mounted) _show('장소 검색에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _placeSearchBusy = false);
    }
  }

  double _distanceFromMapCenter(RaidPlaceSearchResult place) =>
      Geolocator.distanceBetween(
        _mapCenter.latitude,
        _mapCenter.longitude,
        place.latitude,
        place.longitude,
      );

  Future<RaidPlaceSearchResult?> _showPlaceResults(
    List<RaidPlaceSearchResult> results,
  ) => showModalBottomSheet<RaidPlaceSearchResult>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            TtmSpacing.lg,
            TtmSpacing.sm,
            TtmSpacing.lg,
            TtmSpacing.lg,
          ),
          itemCount: results.length + 1,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: TtmSpacing.md),
                child: Text(
                  '검색 결과',
                  style: TtmTypography.title.copyWith(fontSize: 20),
                ),
              );
            }
            final place = results[index - 1];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  place.source == 'local'
                      ? Icons.storefront_rounded
                      : Icons.location_on_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),
              title: Text(
                place.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                place.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(context, place),
            );
          },
        ),
      );
    },
  );

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final latest = now.add(raidDiscoveryWindow);
    final initial = _startsAt.isAfter(latest)
        ? latest
        : _startsAt.isBefore(now)
        ? now
        : _startsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateUtils.dateOnly(latest),
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
        _locationLatitude == null ||
        _locationLongitude == null ||
        _exerciseType == null) {
      if (_locationLatitude == null || _locationLongitude == null) {
        _show('지도에서 운동 장소를 선택해 주세요.');
      } else if (_exerciseType == null) {
        _show('운동 종목을 선택해 주세요.');
      }
      return;
    }
    final now = DateTime.now();
    if (_startsAt.isBefore(now.add(raidMinimumLeadTime))) {
      _show('시작 시간은 지금부터 10분 이후로 설정해 주세요.');
      return;
    }
    if (_startsAt.isAfter(now.add(raidDiscoveryWindow))) {
      _show('레이드는 지금부터 6시간 이내에 시작하도록 설정해 주세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(raidRepositoryProvider)
          .createPremiumRaid(
            locationName: _locationLabel ?? '선택한 운동 장소',
            locationAddress: (_locationAddress?.trim().isNotEmpty ?? false)
                ? _locationAddress!.trim()
                : '${_locationLatitude!.toStringAsFixed(6)}, '
                      '${_locationLongitude!.toStringAsFixed(6)}',
            latitude: _locationLatitude!,
            longitude: _locationLongitude!,
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
        _show('일반 매칭 모집을 시작했어요.');
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
    if (value.contains('premium_required')) {
      return '프리미엄 이용자만 일반 매칭을 만들 수 있어요.';
    }
    if (value.contains('start_time_too_soon')) {
      return '시작 시간을 조금 더 여유 있게 설정해 주세요.';
    }
    if (value.contains('start_time_too_late')) {
      return '레이드는 지금부터 6시간 이내에 시작해야 해요.';
    }
    if (value.contains('invalid_location')) {
      return '지도에서 운동 장소를 다시 선택해 주세요.';
    }
    if (value.contains('exercise_not_supported')) {
      return '이 장소에서 지원하지 않는 운동이에요.';
    }
    return '일반 매칭을 만들지 못했어요. 입력 내용을 확인해 주세요.';
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class _PremiumGate extends StatelessWidget {
  const _PremiumGate({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TtmTierCard(
      tier: TtmCardTier.mission,
      padding: const EdgeInsets.all(TtmSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: colors.primary,
            size: 36,
          ),
          const SizedBox(height: TtmSpacing.md),
          Text(
            '내 운동 매칭을 만들어 보세요',
            style: TtmTypography.title.copyWith(
              color: colors.onSurface,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: TtmSpacing.xs),
          Text(
            '프리미엄 이용자는 일정과 참가 조건을 정하고 참가자를 직접 승인할 수 있어요.',
            style: TtmTypography.body.copyWith(color: colors.onSurfaceVariant),
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
