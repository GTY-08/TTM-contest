import 'package:flutter/foundation.dart';

/// `public.users`의 앱 화면용 프로필 모델.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.nickname,
    required this.email,
    required this.isPremium,
    required this.notificationMode,
    required this.rating,
    required this.ratingCount,
    required this.profileImageUrl,
    required this.onboardingCompletedAt,
    required this.marketingOptIn,
    required this.marketingOptInAt,
    required this.requesterPenaltyUntil,
    required this.workerPenaltyUntil,
    required this.isAdmin,
    required this.createdAt,
  });

  final String id;
  final String nickname;
  final String? email;
  final bool isPremium;
  final String notificationMode;
  final double rating;
  final int ratingCount;
  final String? profileImageUrl;
  final DateTime? onboardingCompletedAt;
  final bool marketingOptIn;
  final DateTime? marketingOptInAt;
  final DateTime? requesterPenaltyUntil;
  final DateTime? workerPenaltyUntil;
  final bool isAdmin;
  final DateTime createdAt;

  bool get hasActiveRequesterPenalty =>
      requesterPenaltyUntil != null &&
      requesterPenaltyUntil!.isAfter(DateTime.now());

  bool get hasActiveWorkerPenalty =>
      workerPenaltyUntil != null && workerPenaltyUntil!.isAfter(DateTime.now());

  bool get isProfileComplete => onboardingCompletedAt != null;

  bool get isFullyOnboarded => isProfileComplete;

  AppUser copyWith({
    String? nickname,
    String? email,
    bool? isPremium,
    String? notificationMode,
    double? rating,
    int? ratingCount,
    String? profileImageUrl,
    DateTime? onboardingCompletedAt,
    bool? marketingOptIn,
    DateTime? marketingOptInAt,
    DateTime? requesterPenaltyUntil,
    DateTime? workerPenaltyUntil,
    bool? isAdmin,
  }) {
    return AppUser(
      id: id,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      isPremium: isPremium ?? this.isPremium,
      notificationMode: notificationMode ?? this.notificationMode,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      marketingOptInAt: marketingOptInAt ?? this.marketingOptInAt,
      requesterPenaltyUntil:
          requesterPenaltyUntil ?? this.requesterPenaltyUntil,
      workerPenaltyUntil: workerPenaltyUntil ?? this.workerPenaltyUntil,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      nickname: (map['nickname'] as String?) ?? '틈틈',
      email: map['email'] as String?,
      isPremium: _asBool(map['is_premium']),
      notificationMode: (map['notification_mode'] as String?) ?? 'push',
      rating: _asDouble(map['rating']) ?? 0,
      ratingCount: _asInt(map['rating_count']) ?? 0,
      profileImageUrl: map['profile_image_url'] as String?,
      onboardingCompletedAt: _parseTs(map['onboarding_completed_at']),
      marketingOptIn: _asBool(map['marketing_opt_in']),
      marketingOptInAt: _parseTs(map['marketing_opt_in_at']),
      requesterPenaltyUntil: _parseTs(map['requester_penalty_until']),
      workerPenaltyUntil: _parseTs(map['worker_penalty_until']),
      isAdmin: _asBool(map['is_admin']),
      createdAt: _parseTs(map['created_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static bool _asBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return false;
  }

  static double? _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
