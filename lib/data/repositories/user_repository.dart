import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/moderation/text_moderation_guard.dart';
import '../models/app_user.dart';
import '../models/received_review.dart';
import '../models/user_restriction.dart';

/// `public.users` 와 관련 RPC 를 호출하는 얇은 래퍼.
class UserRepository {
  UserRepository(this._supabase) : _moderation = TextModerationGuard(_supabase);

  final SupabaseClient _supabase;
  final TextModerationGuard _moderation;

  static const _profileSelect =
      'id,nickname,email,is_premium,notification_mode,rating,rating_count,'
      'profile_image_url,'
      'onboarding_completed_at,'
      'marketing_opt_in,marketing_opt_in_at,requester_penalty_until,'
      'worker_penalty_until,is_admin,created_at';

  /// 현재 로그인 사용자의 `public.users` 행을 가져온다.
  /// 트리거가 자동 생성하므로 통상은 항상 존재. 가입 직후 race 로 null 일 수 있어 nullable 반환.
  Future<AppUser?> fetchUserById(String userId) async {
    final row = await _supabase
        .from('users')
        .select(_profileSelect)
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AppUser.fromMap(Map<String, dynamic>.from(row));
  }

  /// 매칭 상대방 표시용 최소 프로필.
  Future<AppUser?> fetchMatchCounterpartProfile(String requestId) async {
    final rows = await _supabase.rpc(
      'get_match_counterpart_profile',
      params: {'p_request_id': requestId},
    );
    if (rows is! List || rows.isEmpty) return null;
    return AppUser.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<bool> fetchMyAdminRole() async {
    final value = await _supabase.rpc('my_is_admin');
    return value == true;
  }

  Future<List<UserRestriction>> fetchMyActiveRestrictions() async {
    try {
      final raw = await _supabase.rpc('get_my_active_restrictions');
      if (raw is! Map || raw['ok'] != true) return const [];
      final items = raw['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map(
            (item) => UserRestriction.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      final text = '${e.code} ${e.message} ${e.details ?? ''}'.toLowerCase();
      if (text.contains('pgrst202') ||
          text.contains('could not find the function') ||
          text.contains('get_my_active_restrictions')) {
        return const [];
      }
      rethrow;
    }
  }

  Future<List<ReceivedReview>> fetchMyReceivedReviews() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await _supabase
        .from('reviews')
        .select('id, request_id, reviewer_id, rating, comment, created_at')
        .eq('reviewee_id', uid)
        .order('created_at', ascending: false)
        .limit(30);

    return rows
        .map((row) => ReceivedReview.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<AppUser?> fetchMyProfile() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _supabase
        .from('users')
        .select(_profileSelect)
        .eq('id', uid)
        .maybeSingle();

    if (row == null) return null;
    return AppUser.fromMap(row);
  }

  /// 닉네임 중복 여부.
  Future<bool> isNicknameAvailable(String nickname) async {
    final ok = await _supabase.rpc(
      'is_nickname_available',
      params: {'p_nickname': nickname},
    );
    return ok == true;
  }

  /// SignUp 폼 완료 시 호출. 현재 유저 행에 프로필 필드들을 업데이트하고
  /// `onboarding_completed_at` 을 채워 가입 완료 처리한다.
  Future<AppUser> completeOnboarding({
    required String nickname,
    String? profileImageUrl,
    String? notificationMode,
    required bool marketingOptIn,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('not_authenticated');
    }

    await _moderation.ensureAllowed(
      contextType: 'nickname',
      text: nickname,
      targetType: 'user',
      targetId: uid,
    );

    final updates = <String, dynamic>{
      'nickname': nickname,
      'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      'marketing_opt_in': marketingOptIn,
      if (marketingOptIn)
        'marketing_opt_in_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (profileImageUrl != null) {
      updates['profile_image_url'] = profileImageUrl;
    }
    if (notificationMode != null) {
      updates['notification_mode'] = notificationMode;
    }

    final row = await _supabase
        .from('users')
        .update(updates)
        .eq('id', uid)
        .select()
        .single();

    return AppUser.fromMap(row);
  }

  Future<AppUser> updateMyNickname(String nickname) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    await _moderation.ensureAllowed(
      contextType: 'nickname',
      text: nickname,
      targetType: 'user',
      targetId: uid,
    );

    final row = await _supabase
        .from('users')
        .update({'nickname': nickname})
        .eq('id', uid)
        .select()
        .single();

    return AppUser.fromMap(row);
  }

  Future<AppUser> updateNotificationMode(String mode) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final row = await _supabase
        .from('users')
        .update({'notification_mode': mode})
        .eq('id', uid)
        .select()
        .single();

    return AppUser.fromMap(row);
  }

  Future<AppUser> updateMarketingOptIn(bool optIn) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final updates = <String, dynamic>{
      'marketing_opt_in': optIn,
      if (optIn)
        'marketing_opt_in_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await _supabase
        .from('users')
        .update(updates)
        .eq('id', uid)
        .select()
        .single();

    return AppUser.fromMap(row);
  }
}
