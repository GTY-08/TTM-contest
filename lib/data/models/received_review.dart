import 'package:flutter/foundation.dart';

@immutable
class ReceivedReview {
  const ReceivedReview({
    required this.id,
    required this.requestId,
    required this.reviewerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String reviewerId;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  factory ReceivedReview.fromMap(Map<String, dynamic> map) {
    return ReceivedReview(
      id: map['id']?.toString() ?? '',
      requestId: map['request_id']?.toString() ?? '',
      reviewerId: map['reviewer_id']?.toString() ?? '',
      rating: _asInt(map['rating']) ?? 0,
      comment: map['comment']?.toString().trim() ?? '',
      createdAt: _parseTs(map['created_at']),
    );
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
