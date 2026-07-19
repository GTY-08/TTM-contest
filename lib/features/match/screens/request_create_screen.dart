import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart';

import '../../../core/constants/matching_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/concurrent_limit_messages.dart';
import '../../../core/utils/naver_map_support.dart';
import '../../../core/utils/restriction_error_message.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../shared/widgets/ttm_button.dart';
import '../models/general_request_post.dart';
import '../models/request_task_type.dart';
import '../providers/match_providers.dart';
import '../widgets/meet_point_map_picker.dart';

class RequestCreateScreen extends ConsumerStatefulWidget {
  const RequestCreateScreen({
    super.key,
    this.editRequestId,
    this.initialTaskType,
  });

  final String? editRequestId;
  final String? initialTaskType;

  @override
  ConsumerState<RequestCreateScreen> createState() =>
      _RequestCreateScreenState();
}

class _RequestCreateScreenState extends ConsumerState<RequestCreateScreen> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _rewardCtl = TextEditingController();
  final _addressSearchCtl = TextEditingController();
  final _customTagCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _mapKey = GlobalKey<MeetPointMapPickerState>();

  final Set<String> _tags = {};
  String? _taskType;
  bool _taskOptionsConfirmed = false;
  int _waitingDurationMinutes = 60;
  int _proofIntervalMinutes = 30;
  bool _deliveryFragile = false;
  bool _deliveryContactless = false;
  String _deliveryKind = 'delivery';
  int _purchaseBudgetWon = 10000;
  String _cleaningScope = 'small_room';
  String _movingLoad = 'box';
  bool _movingHasElevator = false;
  String _petKind = 'dog';
  int _petCareMinutes = 30;
  int _step = 0;
  String? _matchingMode;
  int _estimatedMinutes = 30;
  int _radiusM = 1000;

  NLatLng _cameraSeed = NLatLng(37.5665, 126.9780);
  double? _meetLat;
  double? _meetLng;
  bool _pickResolved = false;
  bool _gpsBusy = false;
  bool _searchBusy = false;
  bool _initialLocationBusy = false;
  bool _preservePickedLabelOnNextMapUpdate = false;
  bool _submitting = false;
  bool _loadingEdit = false;
  bool _pickingPostImages = false;
  String? _pickedAddressLabel;
  final List<_PostImageDraft> _postImages = [];

  bool get _isEditing => widget.editRequestId != null;
  bool get _isQuick => _matchingMode == 'quick';
  bool get _isGeneral => _matchingMode == 'general';
  Duration get _autoRequestDeadline => const Duration(hours: 24);
  RequestTaskType? get _selectedTaskType =>
      _taskType == null ? null : RequestTaskType.fromId(_taskType);

  Map<String, dynamic> get _taskOptions => switch (_taskType) {
    'delivery' => {
      'service_kind': _deliveryKind,
      'fragile': _deliveryFragile,
      'contactless_delivery': _deliveryContactless,
      'load_size': _movingLoad,
      'has_elevator': _movingHasElevator,
    },
    'purchase' => {
      'purchase_budget_won': _purchaseBudgetWon,
      'receipt_required': true,
    },
    'cleaning' => {'cleaning_scope': _cleaningScope},
    'waiting' => {
      'waiting_duration_minutes': _waitingDurationMinutes,
      'proof_interval_minutes': _proofIntervalMinutes,
      'proof_method': 'photo',
    },
    'pet' => {
      'pet_kind': _petKind,
      'care_duration_minutes': _petCareMinutes,
      'proof_interval_minutes': _proofIntervalMinutes,
    },
    _ => const <String, dynamic>{},
  };

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _matchingMode = 'general';
      unawaited(_loadEditRequest());
    } else {
      final initialTaskType = widget.initialTaskType;
      if (initialTaskType != null &&
          RequestTaskType.values.any((type) => type.id == initialTaskType)) {
        _matchingMode = 'quick';
        _taskType = initialTaskType;
      }
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _rewardCtl.dispose();
    _addressSearchCtl.dispose();
    _customTagCtl.dispose();
    super.dispose();
  }

  Future<void> _loadEditRequest() async {
    setState(() => _loadingEdit = true);
    try {
      final detail = await ref
          .read(matchingRepositoryProvider)
          .fetchGeneralRequestDetail(widget.editRequestId!);
      final req = detail.request;
      if (!mounted) return;
      if (!req.isGeneralMatching || !req.isOpen) {
        _snack('수정할 수 있는 일반 매칭 게시글이 아닙니다.');
        context.go(AppRoutes.home);
        return;
      }
      setState(() {
        _titleCtl.text = req.title ?? '';
        _descCtl.text = req.description;
        _rewardCtl.text = NumberFormat.decimalPattern('ko').format(req.reward);
        _tags
          ..clear()
          ..addAll(req.tags);
        _taskType = req.taskType;
        _taskOptionsConfirmed = true;
        _waitingDurationMinutes =
            req.taskPolicy.waitingDurationMinutes ?? _estimatedMinutes;
        _proofIntervalMinutes = req.taskPolicy.proofIntervalMinutes ?? 30;
        _deliveryFragile = req.taskOptions['fragile'] == true;
        _deliveryContactless = req.taskOptions['contactless_delivery'] == true;
        _deliveryKind = req.taskType == 'moving'
            ? 'transport'
            : (req.taskOptions['service_kind']?.toString() ?? 'delivery');
        _purchaseBudgetWon =
            (req.taskOptions['purchase_budget_won'] as num?)?.toInt() ?? 10000;
        _cleaningScope =
            req.taskOptions['cleaning_scope']?.toString() ?? 'small_room';
        _movingLoad = req.taskOptions['load_size']?.toString() ?? 'box';
        _movingHasElevator = req.taskOptions['has_elevator'] == true;
        _petKind = req.taskOptions['pet_kind']?.toString() ?? 'dog';
        _petCareMinutes =
            (req.taskOptions['care_duration_minutes'] as num?)?.toInt() ?? 30;
        _proofIntervalMinutes =
            (req.taskOptions['proof_interval_minutes'] as num?)?.toInt() ?? 30;
        _estimatedMinutes = req.estimatedTaskMinutes == 0
            ? 30
            : req.estimatedTaskMinutes;
        _meetLat = req.requestLatitude;
        _meetLng = req.requestLongitude;
        _pickResolved = _meetLat != null && _meetLng != null;
        if (_pickResolved) {
          _cameraSeed = NLatLng(_meetLat!, _meetLng!);
        }
        _postImages
          ..clear()
          ..addAll(detail.images.map(_PostImageDraft.remote));
      });
    } catch (e) {
      if (mounted) _snack('게시글을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _loadingEdit = false);
    }
  }

  // ignore: unused_element
  Future<void> _bootstrapMeetCenter() async {
    try {
      final pos = await _obtainReliablePosition();
      if (!mounted) return;
      final point = NLatLng(pos.latitude, pos.longitude);
      setState(() {
        _cameraSeed = point;
        _meetLat = point.latitude;
        _meetLng = point.longitude;
        _pickResolved = true;
        _pickedAddressLabel = '현재 위치';
      });
    } catch (_) {}
  }

  Future<void> _setInitialMeetToCurrentLocation() async {
    if (_isEditing || _pickResolved) return;
    setState(() => _initialLocationBusy = true);
    try {
      final pos = await _obtainReliablePosition();
      if (!mounted) return;
      final point = NLatLng(pos.latitude, pos.longitude);
      setState(() {
        _cameraSeed = point;
        _meetLat = point.latitude;
        _meetLng = point.longitude;
        _pickResolved = true;
        _pickedAddressLabel = '현재 위치';
      });
    } on _LocationFailure catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('현재 위치를 가져오지 못했어요. 지도를 움직여 위치를 정해 주세요.');
    } finally {
      if (mounted) setState(() => _initialLocationBusy = false);
    }
  }

  Future<Position> _obtainReliablePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const _LocationFailure('기기의 위치 서비스를 켜 주세요.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw const _LocationFailure('위치 권한을 허용해 주세요.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 12),
    );
  }

  Future<void> _recenterMeetToMyLocation() async {
    if (_gpsBusy) return;
    setState(() => _gpsBusy = true);
    try {
      final pos = await _obtainReliablePosition();
      if (!mounted) return;
      final point = NLatLng(pos.latitude, pos.longitude);
      setState(() {
        _cameraSeed = point;
        _meetLat = point.latitude;
        _meetLng = point.longitude;
        _pickResolved = true;
        _pickedAddressLabel = '현재 위치';
        _preservePickedLabelOnNextMapUpdate = true;
      });
      await _mapKey.currentState?.moveTo(point, zoom: 17);
      _snack('현재 위치로 이동했습니다.');
    } on _LocationFailure catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('현재 위치를 가져오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  String? _normalizeCustomTag(String raw) {
    final tag = raw.replaceAll('#', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (tag.isEmpty) return null;
    return tag.length > 16 ? tag.substring(0, 16) : tag;
  }

  void _addCustomTag() {
    final tag = _normalizeCustomTag(_customTagCtl.text);
    if (tag == null) {
      _snack('추가할 태그를 입력해 주세요.');
      return;
    }
    if (_tags.length >= 8 && !_tags.contains(tag)) {
      _snack('태그는 최대 8개까지 사용할 수 있어요.');
      return;
    }
    setState(() {
      _tags.add(tag);
      _customTagCtl.clear();
    });
  }

  void _goStep2() {
    if (_matchingMode == null) {
      _snack('매칭 방식을 먼저 선택해 주세요.');
      return;
    }
    if (_taskType == null || !_taskOptionsConfirmed) {
      _snack('○○ 유형과 유형별 조건을 먼저 확인해 주세요.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _step = 1;
      if (!_isEditing) {
        _pickResolved = false;
        _meetLat = null;
        _meetLng = null;
        _pickedAddressLabel = null;
        _addressSearchCtl.clear();
      }
    });
    if (!_pickResolved) unawaited(_setInitialMeetToCurrentLocation());
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_matchingMode == null) {
      _snack('매칭 방식을 선택해 주세요.');
      return;
    }
    if (!_pickResolved || _meetLat == null || _meetLng == null) {
      _snack(
        ttmSupportsEmbeddedNaverMap ? '지도에서 위치를 정해 주세요.' : 'GPS로 위치를 잡아 주세요.',
      );
      return;
    }

    final reward =
        num.tryParse(_rewardCtl.text.replaceAll(',', '').trim()) ?? 0;
    final deadline = DateTime.now().add(_autoRequestDeadline);
    if (_estimatedMinutes < 5 || _estimatedMinutes > 720) {
      _snack('예상 소요 시간은 5분부터 12시간까지 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(matchingRepositoryProvider);
      if (_isEditing) {
        await repo.updateGeneralRequestPost(
          requestId: widget.editRequestId!,
          title: _titleCtl.text.trim(),
          description: _descCtl.text.trim(),
          tags: _tags.toList(),
          taskType: _taskType!,
          taskOptions: _taskOptions,
          reward: reward,
          latitude: _meetLat!,
          longitude: _meetLng!,
          deadline: deadline,
          estimatedTaskMinutes: _estimatedMinutes,
        );
        await _syncPostImages(widget.editRequestId!);
        ref.invalidate(myOpenGeneralRequestsProvider);
        ref.invalidate(generalRequestDetailProvider(widget.editRequestId!));
        if (!mounted) return;
        _snack('게시글을 수정했습니다.');
        context.go('${AppRoutes.requestRoot}/${widget.editRequestId}/general');
        return;
      }

      final req = await repo.createOpenRequest(
        title: _isGeneral ? _titleCtl.text.trim() : null,
        description: _descCtl.text.trim(),
        tags: _tags.toList(),
        taskType: _taskType!,
        taskOptions: _taskOptions,
        reward: reward,
        rewardMax: null,
        latitude: _meetLat!,
        longitude: _meetLng!,
        deadline: deadline,
        estimatedTaskMinutes: _estimatedMinutes,
        maxSearchRadiusM: _isQuick ? _radiusM : 1,
        notes: null,
        stageIntervalSeconds: TtmMatchingConstants.defaultStageIntervalSeconds,
        matchingMode: _matchingMode!,
      );
      if (!mounted) return;
      if (_isQuick) {
        context.go('${AppRoutes.requestRoot}/${req.id}/waiting');
      } else {
        await _syncPostImages(req.id);
        await ref.read(prefsProvider).clearWaitingMatchRequestId();
        if (!mounted) return;
        ref.invalidate(myOpenGeneralRequestsProvider);
        _snack('일반 매칭 게시글을 올렸습니다.');
        context.go('${AppRoutes.requestRoot}/${req.id}/general');
      }
    } catch (e) {
      final premium =
          ref.read(myProfileProvider).valueOrNull?.isPremium ?? false;
      final limitMsg = concurrentLimitUserMessage(e, isPremium: premium);
      final restrictionMsg = restrictionErrorMessage(e);
      _snack(
        restrictionMsg.isNotEmpty
            ? restrictionMsg
            : (limitMsg.isNotEmpty ? limitMsg : _requestCreateErrorMessage(e)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _syncPostImages(String requestId) async {
    if (!_isGeneral) return;
    final repo = ref.read(matchingRepositoryProvider);
    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < _postImages.length; i++) {
      final item = _postImages[i];
      final remote = item.remote;
      if (remote != null) {
        payload.add(remote.toReplacePayload(i));
        continue;
      }
      final file = item.file;
      if (file == null) continue;
      final uploaded = await repo.uploadGeneralPostImage(
        requestId: requestId,
        file: file,
      );
      payload.add(uploaded.toReplacePayload(i));
    }
    await repo.replaceGeneralRequestImages(
      requestId: requestId,
      images: payload,
    );
  }

  Future<void> _pickPostImages() async {
    if (_pickingPostImages) return;
    final remaining = 10 - _postImages.length;
    if (remaining <= 0) {
      _snack('사진은 최대 10장까지 올릴 수 있습니다.');
      return;
    }
    setState(() => _pickingPostImages = true);
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (!mounted || picked.isEmpty) return;
      final selected = picked.take(remaining).map((x) => File(x.path));
      setState(() {
        _postImages.addAll(selected.map(_PostImageDraft.local));
      });
      if (picked.length > remaining) {
        _snack('최대 10장까지만 추가했습니다.');
      }
    } catch (e) {
      if (mounted) _snack('사진을 선택하지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _pickingPostImages = false);
    }
  }

  void _removePostImage(int index) {
    setState(() => _postImages.removeAt(index));
  }

  void _movePostImage(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _postImages.length) return;
    setState(() {
      final item = _postImages.removeAt(index);
      _postImages.insert(target, item);
    });
  }

  Future<void> _useGpsAsMeetFallback() async {
    if (_gpsBusy) return;
    setState(() => _gpsBusy = true);
    try {
      final pos = await _obtainReliablePosition();
      if (!mounted) return;
      setState(() {
        _meetLat = pos.latitude;
        _meetLng = pos.longitude;
        _pickResolved = true;
      });
      _snack('GPS 위치로 설정했습니다.');
    } on _LocationFailure catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('위치를 가져오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<void> _searchAddress() async {
    final q = _addressSearchCtl.text.trim();
    if (q.length < 2) {
      _snack('두 글자 이상 입력해 주세요.');
      return;
    }
    if (_searchBusy) return;
    setState(() => _searchBusy = true);
    try {
      final hits = await _searchPlaces(q);
      if (!mounted) return;
      if (hits.isEmpty) {
        _snack('검색 결과가 없습니다. 다른 단어로 시도해 주세요.');
        return;
      }
      final hit = hits.length == 1 ? hits.first : await _showPlaceResults(hits);
      if (hit == null || !mounted) return;
      final point = hit.point;
      if (point == null) return;
      setState(() {
        _cameraSeed = point;
        _meetLat = point.latitude;
        _meetLng = point.longitude;
        _pickResolved = true;
        _pickedAddressLabel = hit.label;
        _preservePickedLabelOnNextMapUpdate = true;
      });
      await _mapKey.currentState?.moveTo(point, zoom: 17);
      _snack('위치를 찾았습니다.');
    } on _PlaceSearchException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('주소 검색에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _searchBusy = false);
    }
  }

  Future<List<_PlaceSearchResult>> _searchPlaces(String query) async {
    final response = await ref
        .read(supabaseClientProvider)
        .functions
        .invoke('place-search', body: {'q': query});
    final data = response.data;
    if (data is! Map) return const [];
    final map = Map<String, dynamic>.from(data);
    if (map['ok'] != true) {
      throw _PlaceSearchException(map['reason']?.toString() ?? 'search_failed');
    }
    final rawItems = map['items'];
    if (rawItems is! List) return const [];
    final origin = _currentSearchOrigin();
    final items = rawItems
        .whereType<Map>()
        .map(
          (item) => _PlaceSearchResult.fromMap(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.point != null)
        .toList(growable: false);
    return [
      ...items,
    ]..sort((a, b) => a.distanceFrom(origin).compareTo(b.distanceFrom(origin)));
  }

  NLatLng _currentSearchOrigin() {
    final lat = _meetLat;
    final lng = _meetLng;
    if (lat != null && lng != null) return NLatLng(lat, lng);
    return _cameraSeed;
  }

  Future<_PlaceSearchResult?> _showPlaceResults(
    List<_PlaceSearchResult> items,
  ) {
    return showModalBottomSheet<_PlaceSearchResult>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final origin = _currentSearchOrigin();
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              TtmSpacing.lg,
              TtmSpacing.sm,
              TtmSpacing.lg,
              TtmSpacing.lg,
            ),
            itemCount: items.length + 1,
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
                    style: TtmTypography.title.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }
              final item = items[index - 1];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    item.source == 'local'
                        ? Icons.storefront_rounded
                        : Icons.location_on_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TtmTypography.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  item.subtitle(origin),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        );
      },
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _requestCreateErrorMessage(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? 'no_code';
      final message = error.message.trim();
      final lower = message.toLowerCase();
      if (code == 'PGRST202' ||
          lower.contains('could not find the function') ||
          lower.contains('schema cache')) {
        return '요청 생성 함수 캐시가 맞지 않습니다. 잠시 후 다시 시도해 주세요. ($code)';
      }
      if (message == 'concurrent_slot_limit') {
        return '동시에 진행할 수 있는 작업 수를 초과했습니다.';
      }
      if (message == 'not_authenticated') {
        return '로그인 세션이 만료되었습니다. 다시 로그인해 주세요.';
      }
      final short = message.length > 90
          ? '${message.substring(0, 90)}...'
          : message;
      return '요청 생성 실패: $short ($code)';
    }
    final text = error.toString();
    if (text.contains('general_matching_db_migration_required')) {
      return '일반 매칭 DB 업데이트가 필요합니다. 새 SQL을 Supabase에 적용해 주세요.';
    }
    if (text.contains('PGRST202') || text.contains('schema cache')) {
      return '요청 생성 DB 함수가 앱 버전과 맞지 않습니다. SQL 적용 상태를 확인해 주세요.';
    }
    return '요청을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final won = NumberFormat.decimalPattern('ko');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '게시글 수정' : (_step == 0 ? '○○ 요청' : '위치와 시간')),
        scrolledUnderElevation: 0,
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: '이전 단계',
                onPressed: () => setState(() => _step = 0),
              ),
      ),
      body: SafeArea(
        child: _loadingEdit
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TtmSpacing.xl,
                      TtmSpacing.sm,
                      TtmSpacing.xl,
                      TtmSpacing.sm,
                    ),
                    child: _StepProgressBar(step: _step),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: TtmMotion.slow,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey<int>(_step),
                        child: _step == 0
                            ? _buildStepDetails(context, colors, won)
                            : _buildStepMeetPlace(context, colors),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStepDetails(
    BuildContext context,
    ColorScheme colors,
    NumberFormat won,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          TtmSpacing.xl,
          TtmSpacing.sm,
          TtmSpacing.xl,
          TtmSpacing.xxl,
        ),
        children: [
          if (!_isEditing) ...[
            _SectionTitle('매칭 방식'),
            const SizedBox(height: TtmSpacing.sm),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: TtmColors.primaryLight,
                selectedForegroundColor: TtmColors.deepGreen,
              ),
              segments: const [
                ButtonSegment(
                  value: 'quick',
                  icon: Icon(Icons.radar_rounded),
                  label: Text('빠른 매칭'),
                ),
                ButtonSegment(
                  value: 'general',
                  icon: Icon(Icons.forum_rounded),
                  label: Text('일반 매칭'),
                ),
              ],
              selected: _matchingMode == null ? const {} : {_matchingMode!},
              onSelectionChanged: (value) {
                setState(() {
                  _matchingMode = value.isEmpty ? null : value.first;
                  _taskType = null;
                  _taskOptionsConfirmed = false;
                  _tags.clear();
                });
              },
            ),
            const SizedBox(height: TtmSpacing.sm),
            if (_matchingMode == null)
              Text(
                '방식을 선택하면 작성 항목이 표시됩니다.',
                style: TtmTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (_matchingMode != null)
              Text(
                _isQuick
                    ? '주변 작업자를 거리 기반으로 바로 찾습니다.'
                    : '게시글을 올리고, 연락한 작업자 중 직접 선택합니다.',
                style: TtmTypography.body.copyWith(
                  fontSize: 13,
                  height: 1.35,
                  color: colors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: TtmSpacing.xl),
          ],
          if (_matchingMode != null || _isEditing) ...[
            _SectionTitle('○○ 유형'),
            const SizedBox(height: TtmSpacing.sm),
            Wrap(
              spacing: TtmSpacing.sm,
              runSpacing: TtmSpacing.sm,
              children: [
                for (final type in RequestTaskType.values)
                  _TagChip(
                    label: type.label,
                    selected: _taskType == type.id,
                    onTap: () => setState(() {
                      _taskType = type.id;
                      _taskOptionsConfirmed = false;
                      _tags.clear();
                    }),
                  ),
              ],
            ),
            if (_selectedTaskType != null) ...[
              const SizedBox(height: TtmSpacing.sm),
              Text(
                _selectedTaskType!.description,
                style: TtmTypography.body.copyWith(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TtmSpacing.lg),
              _buildTaskTypeOptions(colors),
            ],
          ],
          if (_taskOptionsConfirmed) ...[
            const SizedBox(height: TtmSpacing.xl),
            if (_isGeneral) ...[
              _SectionTitle('제목'),
              const SizedBox(height: TtmSpacing.md),
              TextFormField(
                controller: _titleCtl,
                maxLength: 40,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: '예: 강남역 근처 서류 전달'),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? '제목을 2자 이상 입력해 주세요.' : null,
              ),
              const SizedBox(height: TtmSpacing.lg),
            ],
            _SectionTitle('내용'),
            const SizedBox(height: TtmSpacing.md),
            TextFormField(
              controller: _descCtl,
              maxLines: 4,
              minLines: 2,
              maxLength: _isGeneral ? 500 : 200,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: _isGeneral
                    ? '작업 내용, 희망 시간, 전달 사항을 자세히 적어 주세요.'
                    : '예: 1층 무인택배함에서 4층 304호로 가져다 주세요.',
              ),
              validator: (v) =>
                  v == null || v.trim().length < 5 ? '5자 이상 적어 주세요.' : null,
            ),
            const SizedBox(height: TtmSpacing.xl),
            if (_isGeneral) ...[
              _SectionTitle('사진'),
              const SizedBox(height: TtmSpacing.sm),
              _PostImagePicker(
                images: _postImages,
                picking: _pickingPostImages,
                onAdd: _pickPostImages,
                onRemove: _removePostImage,
                onMove: _movePostImage,
              ),
              const SizedBox(height: TtmSpacing.xl),
            ],
            _SectionTitle(_isGeneral ? '제안 ○○비' : '보상'),
            const SizedBox(height: TtmSpacing.md),
            TextFormField(
              controller: _rewardCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ThousandsFormatter(won),
              ],
              decoration: const InputDecoration(
                hintText: '금액 입력',
                suffixText: '원',
              ),
              validator: (v) {
                final n = num.tryParse((v ?? '').replaceAll(',', '').trim());
                return n == null || n < 1000 ? '1,000원 이상으로 적어 주세요.' : null;
              },
            ),
            if (_isGeneral) ...[
              const SizedBox(height: TtmSpacing.sm),
              Text(
                '작업자와 채팅을 통해 최종 ○○비를 조절할 수 있어요.',
                style: TtmTypography.body.copyWith(
                  fontSize: 13,
                  height: 1.35,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: TtmSpacing.xl),
            _SectionTitle('태그'),
            const SizedBox(height: TtmSpacing.sm),
            Wrap(
              spacing: TtmSpacing.sm,
              runSpacing: TtmSpacing.sm,
              children: [
                for (final tag in _tags.where(
                  (tag) => !RequestTaskType.values.any(
                    (type) => type.legacyTag == tag,
                  ),
                ))
                  InputChip(
                    label: Text('#$tag'),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: TtmSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTagCtl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addCustomTag(),
                    decoration: const InputDecoration(
                      hintText: '직접 태그 입력',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: TtmSpacing.sm),
                FilledButton.tonal(
                  onPressed: _addCustomTag,
                  child: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: TtmSpacing.xxxl),
            TTMButton(label: '다음', onPressed: _goStep2),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskTypeOptions(ColorScheme colors) {
    final isWaiting = _taskType == RequestTaskType.waiting.id;
    return Container(
      padding: const EdgeInsets.all(TtmSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isWaiting ? '대기 조건' : '유형 확인',
            style: TtmTypography.title.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (isWaiting) ...[
            const SizedBox(height: TtmSpacing.md),
            const Text('총 대기시간'),
            const SizedBox(height: TtmSpacing.sm),
            _MinuteTuner(
              value: _waitingDurationMinutes,
              minMinutes: 15,
              maxMinutes: 720,
              stepMinutes: 5,
              presets: const [30, 60, 120, 240],
              onChanged: (minutes) => setState(() {
                _waitingDurationMinutes = minutes;
                _estimatedMinutes = minutes;
                _taskOptionsConfirmed = false;
              }),
            ),
            const SizedBox(height: TtmSpacing.md),
            const Text('대기 인증 사진 간격'),
            const SizedBox(height: TtmSpacing.sm),
            _MinuteTuner(
              value: _proofIntervalMinutes,
              minMinutes: 15,
              maxMinutes: 60,
              stepMinutes: 5,
              presets: const [15, 30, 45, 60],
              suffix: '마다',
              onChanged: (minutes) => setState(() {
                _proofIntervalMinutes = minutes;
                _taskOptionsConfirmed = false;
              }),
            ),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              '대기형은 위치가 오래 변하지 않아도 정상입니다. 진행 중에는 선택한 간격마다 현장 인증 사진이 필요합니다.',
              style: TtmTypography.body.copyWith(
                fontSize: 13,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(height: TtmSpacing.sm),
            _buildNonWaitingTaskOptions(colors),
          ],
          const SizedBox(height: TtmSpacing.md),
          OutlinedButton(
            onPressed: () => setState(() => _taskOptionsConfirmed = true),
            child: Text(_taskOptionsConfirmed ? '확인 완료' : '이 조건으로 계속'),
          ),
        ],
      ),
    );
  }

  Widget _buildNonWaitingTaskOptions(ColorScheme colors) {
    Widget choices(
      List<({String value, String label})> items,
      String selected,
      ValueChanged<String> onSelected,
    ) {
      return Wrap(
        spacing: TtmSpacing.sm,
        runSpacing: TtmSpacing.sm,
        children: [
          for (final item in items)
            _OptionChip(
              label: item.label,
              selected: selected == item.value,
              onTap: () => setState(() {
                onSelected(item.value);
                _taskOptionsConfirmed = false;
              }),
            ),
        ],
      );
    }

    switch (_taskType) {
      case 'delivery':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            choices(
              const [
                (value: 'delivery', label: '배달'),
                (value: 'transport', label: '짐 운반'),
              ],
              _deliveryKind,
              (value) => _deliveryKind = value,
            ),
            if (_deliveryKind == 'delivery') ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('파손 주의 물품'),
                value: _deliveryFragile,
                onChanged: (value) => setState(() {
                  _deliveryFragile = value;
                  _taskOptionsConfirmed = false;
                }),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('비대면 전달'),
                value: _deliveryContactless,
                onChanged: (value) => setState(() {
                  _deliveryContactless = value;
                  _taskOptionsConfirmed = false;
                }),
              ),
            ] else ...[
              const SizedBox(height: TtmSpacing.md),
              choices(
                const [
                  (value: 'bag', label: '가방 크기'),
                  (value: 'box', label: '박스 여러 개'),
                  (value: 'furniture', label: '가구·대형'),
                ],
                _movingLoad,
                (value) => _movingLoad = value,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('엘리베이터 이용 가능'),
                value: _movingHasElevator,
                onChanged: (value) => setState(() {
                  _movingHasElevator = value;
                  _taskOptionsConfirmed = false;
                }),
              ),
            ],
          ],
        );
      case 'purchase':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('구매 예산 상한'),
            const SizedBox(height: TtmSpacing.sm),
            choices(
              const [
                (value: '10000', label: '1만원'),
                (value: '30000', label: '3만원'),
                (value: '50000', label: '5만원'),
                (value: '100000', label: '10만원'),
              ],
              '$_purchaseBudgetWon',
              (value) => _purchaseBudgetWon = int.parse(value),
            ),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              '구매 완료 시 영수증 인증이 필요합니다.',
              style: TtmTypography.body.copyWith(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        );
      case 'cleaning':
        return choices(
          const [
            (value: 'small_room', label: '방 1개'),
            (value: 'home', label: '주거 공간'),
            (value: 'office', label: '사무 공간'),
          ],
          _cleaningScope,
          (value) => _cleaningScope = value,
        );
      case 'pet':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            choices(
              const [
                (value: 'dog', label: '강아지'),
                (value: 'cat', label: '고양이'),
                (value: 'person', label: '사람 돌봄'),
                (value: 'other', label: '기타'),
              ],
              _petKind,
              (value) => _petKind = value,
            ),
            const SizedBox(height: TtmSpacing.md),
            const Text('돌봄 시간'),
            const SizedBox(height: TtmSpacing.sm),
            _MinuteTuner(
              value: _petCareMinutes,
              minMinutes: 15,
              maxMinutes: 720,
              stepMinutes: 5,
              presets: const [30, 60, 120, 240],
              onChanged: (minutes) => setState(() {
                _petCareMinutes = minutes;
                _taskOptionsConfirmed = false;
              }),
            ),
            const SizedBox(height: TtmSpacing.md),
            const Text('돌봄 인증 사진 간격'),
            const SizedBox(height: TtmSpacing.sm),
            _MinuteTuner(
              value: _proofIntervalMinutes,
              minMinutes: 15,
              maxMinutes: 60,
              stepMinutes: 5,
              presets: const [15, 30, 45, 60],
              suffix: '마다',
              onChanged: (minutes) => setState(() {
                _proofIntervalMinutes = minutes;
                _taskOptionsConfirmed = false;
              }),
            ),
            const SizedBox(height: TtmSpacing.sm),
            Text(
              '돌봄도 대기형처럼 진행 중 선택한 간격마다 인증 사진을 제출해야 완료할 수 있어요.',
              style: TtmTypography.body.copyWith(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      default:
        return Text(
          '상세 조건은 아래 내용에 구체적으로 적어 주세요.',
          style: TtmTypography.body.copyWith(
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        );
    }
  }

  Widget _buildStepMeetPlace(BuildContext context, ColorScheme colors) {
    const mapHeight = 260.0;

    if (_initialLocationBusy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(TtmSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: TtmSpacing.md),
              Text('현재 위치를 확인하고 있어요.'),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.xl,
        TtmSpacing.sm,
        TtmSpacing.xl,
        TtmSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeetPointMapPicker(
            key: _mapKey,
            initialCenter: _cameraSeed,
            height: mapHeight,
            onPickChanged: (lat, lng) {
              final preserveLabel = _preservePickedLabelOnNextMapUpdate;
              setState(() {
                _meetLat = lat;
                _meetLng = lng;
                _pickResolved = true;
                if (!preserveLabel) _pickedAddressLabel = null;
                _preservePickedLabelOnNextMapUpdate = false;
              });
            },
          ),
          const SizedBox(height: TtmSpacing.lg),
          _SectionTitle(_isGeneral ? '작업 위치' : '만날 위치'),
          const SizedBox(height: TtmSpacing.sm),
          TextField(
            controller: _addressSearchCtl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchAddress(),
            decoration: InputDecoration(
              hintText: '주소나 장소 검색',
              suffixIcon: _searchBusy
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _searchAddress,
                      icon: const Icon(Icons.search_rounded),
                      tooltip: '검색',
                    ),
            ),
          ),
          const SizedBox(height: TtmSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _pickResolved && _pickedAddressLabel != null
                    ? Text(
                        _pickedAddressLabel!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TtmTypography.label.copyWith(
                          fontSize: 13,
                          color: colors.onSurface,
                          height: 1.35,
                        ),
                      )
                    : _pickResolved && _meetLat != null && _meetLng != null
                    ? Text(
                        '${_meetLat!.toStringAsFixed(5)}, ${_meetLng!.toStringAsFixed(5)}',
                        style: TtmTypography.label.copyWith(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : Text(
                        '지도를 움직여 위치를 정해 주세요.',
                        style: TtmTypography.label.copyWith(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
              ),
              TextButton.icon(
                onPressed: _gpsBusy ? null : _recenterMeetToMyLocation,
                icon: _gpsBusy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Icon(Icons.my_location_rounded, color: colors.primary),
                label: Text(
                  '내 위치',
                  style: TtmTypography.title.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (!ttmSupportsEmbeddedNaverMap) ...[
            const SizedBox(height: TtmSpacing.sm),
            OutlinedButton.icon(
              onPressed: _gpsBusy ? null : _useGpsAsMeetFallback,
              icon: const Icon(Icons.gps_fixed_rounded),
              label: Text(
                _gpsBusy ? '확인 중' : 'GPS로 위치 설정',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: TtmSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: TtmSpacing.lg),
          _SectionTitle(
            _taskType == RequestTaskType.waiting.id ? '대기 시간' : '예상 소요 시간',
          ),
          const SizedBox(height: TtmSpacing.sm),
          if (_taskType == RequestTaskType.waiting.id)
            Text(
              '${_minutesLabel(_waitingDurationMinutes)} · '
              '$_proofIntervalMinutes분마다 사진 인증',
              style: TtmTypography.title.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            _MinuteTuner(
              value: _estimatedMinutes,
              minMinutes: 5,
              maxMinutes: 720,
              stepMinutes: 5,
              presets: const [15, 30, 60, 120],
              onChanged: (minutes) =>
                  setState(() => _estimatedMinutes = minutes),
            ),
          if (_isQuick) ...[
            const SizedBox(height: TtmSpacing.lg),
            _SectionTitle('거리 범위'),
            const SizedBox(height: TtmSpacing.sm),
            Wrap(
              spacing: TtmSpacing.sm,
              runSpacing: TtmSpacing.sm,
              children: [
                for (final r in const [500, 1000, 2000, 5000])
                  _OptionChip(
                    label: r >= 1000 ? '${r ~/ 1000}km' : '${r}m',
                    selected: _radiusM == r,
                    onTap: () => setState(() => _radiusM = r),
                  ),
              ],
            ),
          ],
          const SizedBox(height: TtmSpacing.lg),
          TTMButton(
            label: _isEditing
                ? '게시글 수정'
                : (_isGeneral ? '게시글 올리기' : '주변에 요청 올리기'),
            busy: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  static String _minutesLabel(int m) {
    if (m < 60) return '$m분';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '$h시간';
    return '$h시간 $r분';
  }
}

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).brightness == Brightness.dark
        ? TtmColors.primaryDark
        : TtmColors.primary;
    final t = (step.clamp(0, 1) + 1) / 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step == 0 ? '1 / 2' : '2 / 2',
          style: TtmTypography.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: t,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.65,
            ),
            color: primary,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TtmTypography.title.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: colors.onSurface,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filled = isDark ? TtmColors.primaryDark : TtmColors.primary;
    final neutralBg = isDark
        ? TtmColors.darkSurfaceAlt
        : TtmColors.lightSurfaceAlt;

    return InkWell(
      borderRadius: BorderRadius.circular(TtmRadius.pill),
      onTap: onTap,
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
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TtmColors.primaryDark : TtmColors.primary;
    final neutralBg = isDark
        ? TtmColors.darkSurfaceAlt
        : TtmColors.lightSurfaceAlt;
    return InkWell(
      borderRadius: BorderRadius.circular(TtmRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: TtmSpacing.lg,
          vertical: TtmSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.22 : 0.12)
              : neutralBg,
          borderRadius: BorderRadius.circular(TtmRadius.md),
          border: Border.all(
            color: selected
                ? accent
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TtmTypography.title.copyWith(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: selected ? accent : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MinuteTuner extends StatelessWidget {
  const _MinuteTuner({
    required this.value,
    required this.minMinutes,
    required this.maxMinutes,
    required this.onChanged,
    this.stepMinutes = 5,
    this.presets = const [],
    this.suffix = '',
  });

  final int value;
  final int minMinutes;
  final int maxMinutes;
  final int stepMinutes;
  final List<int> presets;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final clamped = value.clamp(minMinutes, maxMinutes);
    final divisions = ((maxMinutes - minMinutes) / stepMinutes).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        TtmSpacing.md,
        TtmSpacing.sm,
        TtmSpacing.md,
        TtmSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TtmRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                _format(clamped, suffix),
                style: TtmTypography.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${_format(minMinutes)}~${_format(maxMinutes)}',
                style: TtmTypography.label.copyWith(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            min: minMinutes.toDouble(),
            max: maxMinutes.toDouble(),
            divisions: divisions <= 0 ? null : divisions,
            value: clamped.toDouble(),
            label: _format(clamped, suffix),
            onChanged: (raw) => onChanged(_snap(raw)),
          ),
          if (presets.isNotEmpty)
            Wrap(
              spacing: TtmSpacing.xs,
              runSpacing: TtmSpacing.xs,
              children: [
                for (final preset in presets)
                  _OptionChip(
                    label: _format(preset, suffix),
                    selected: clamped == preset,
                    onTap: () => onChanged(preset),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  int _snap(double raw) {
    final snapped = (raw / stepMinutes).round() * stepMinutes;
    return snapped.clamp(minMinutes, maxMinutes);
  }

  static String _format(int minutes, [String suffix = '']) {
    final base = minutes < 60
        ? '$minutes분'
        : minutes % 60 == 0
        ? '${minutes ~/ 60}시간'
        : '${minutes ~/ 60}시간 ${minutes % 60}분';
    return suffix.isEmpty ? base : '$base $suffix';
  }
}

class _PostImageDraft {
  const _PostImageDraft._({this.file, this.remote});

  factory _PostImageDraft.local(File file) => _PostImageDraft._(file: file);
  factory _PostImageDraft.remote(GeneralRequestPostImage image) =>
      _PostImageDraft._(remote: image);

  final File? file;
  final GeneralRequestPostImage? remote;
}

class _PostImagePicker extends StatelessWidget {
  const _PostImagePicker({
    required this.images,
    required this.picking,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
  });

  final List<_PostImageDraft> images;
  final bool picking;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, int delta) onMove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + (images.length < 10 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: TtmSpacing.sm),
            itemBuilder: (context, index) {
              if (index == images.length) {
                return _AddPhotoTile(
                  picking: picking,
                  count: images.length,
                  onTap: onAdd,
                );
              }
              return _PostImageThumb(
                item: images[index],
                index: index,
                total: images.length,
                onRemove: () => onRemove(index),
                onMoveLeft: () => onMove(index, -1),
                onMoveRight: () => onMove(index, 1),
              );
            },
          ),
        ),
        const SizedBox(height: TtmSpacing.xs),
        Text(
          '최대 10장까지 올릴 수 있습니다. 첫 사진이 목록 대표 이미지로 표시됩니다.',
          style: TtmTypography.body.copyWith(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.picking,
    required this.count,
    required this.onTap,
  });

  final bool picking;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: picking ? null : onTap,
      borderRadius: BorderRadius.circular(TtmRadius.md),
      child: Container(
        width: 92,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(TtmRadius.md),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Center(
          child: picking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined),
                    const SizedBox(height: 4),
                    Text(
                      '$count/10',
                      style: TtmTypography.label.copyWith(fontSize: 12),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PostImageThumb extends StatelessWidget {
  const _PostImageThumb({
    required this.item,
    required this.index,
    required this.total,
    required this.onRemove,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  final _PostImageDraft item;
  final int index;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final file = item.file;
    final image = file != null
        ? Image.file(file, fit: BoxFit.cover)
        : Image.network(item.remote?.imageUrl ?? '', fit: BoxFit.cover);

    return ClipRRect(
      borderRadius: BorderRadius.circular(TtmRadius.md),
      child: SizedBox(
        width: 92,
        height: 92,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              top: 4,
              right: 4,
              child: _ThumbIconButton(
                icon: Icons.close_rounded,
                onTap: onRemove,
              ),
            ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ThumbIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: index == 0 ? null : onMoveLeft,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(TtmRadius.pill),
                    ),
                    child: Text(
                      index == 0 ? '대표' : '${index + 1}',
                      style: TtmTypography.label.copyWith(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _ThumbIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: index == total - 1 ? null : onMoveRight,
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(TtmRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbIconButton extends StatelessWidget {
  const _ThumbIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TtmRadius.pill),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.black.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _PlaceSearchResult {
  const _PlaceSearchResult({
    required this.label,
    required this.address,
    required this.source,
    required this.point,
  });

  factory _PlaceSearchResult.fromMap(Map<String, dynamic> map) {
    final lat = _asDouble(map['lat']);
    final lng = _asDouble(map['lng']);
    final name = (map['name'] ?? '').toString().trim();
    final road = (map['roadAddress'] ?? '').toString().trim();
    final jibun = (map['jibunAddress'] ?? '').toString().trim();
    return _PlaceSearchResult(
      label: name.isNotEmpty ? name : (road.isNotEmpty ? road : jibun),
      address: road.isNotEmpty ? road : jibun,
      source: (map['source'] ?? '').toString(),
      point: lat != null && lng != null ? NLatLng(lat, lng) : null,
    );
  }

  final String label;
  final String address;
  final String source;
  final NLatLng? point;

  double distanceFrom(NLatLng origin) {
    final p = point;
    if (p == null) return double.infinity;
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      p.latitude,
      p.longitude,
    );
  }

  String subtitle(NLatLng origin) {
    final distance = distanceFrom(origin);
    final distanceText = distance.isFinite
        ? (distance >= 1000
              ? '${(distance / 1000).toStringAsFixed(1)}km'
              : '${distance.round()}m')
        : '';
    final sourceText = source == 'local' ? '장소' : '주소';
    final parts = [
      if (address.isNotEmpty) address,
      if (distanceText.isNotEmpty) distanceText,
      sourceText,
    ];
    return parts.join(' · ');
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _PlaceSearchException implements Exception {
  const _PlaceSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _LocationFailure {
  const _LocationFailure(this.message);
  final String message;
}

class _ThousandsFormatter extends TextInputFormatter {
  _ThousandsFormatter(this._fmt);
  final NumberFormat _fmt;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final num? n = num.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = _fmt.format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
