import 'package:flutter/foundation.dart';

@immutable
class UserRestriction {
  const UserRestriction({
    required this.id,
    required this.type,
    required this.reason,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String reason;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  bool get isWarning => type == 'warning';
  bool get isSuspended => type == 'suspended';
  bool get blocksRequest =>
      isSuspended || type == 'request_block' || type == 'matching_block';
  bool get blocksWorker =>
      isSuspended || type == 'worker_block' || type == 'matching_block';
  bool get blocksChat => isSuspended || type == 'chat_block';

  int get severityRank {
    return switch (type) {
      'suspended' => 0,
      'request_block' => 1,
      'worker_block' => 2,
      'matching_block' => 3,
      'chat_block' => 4,
      'warning' => 5,
      _ => 6,
    };
  }

  String get typeLabel {
    return switch (type) {
      'warning' => '경고',
      'request_block' => '요청 제한',
      'worker_block' => '작업 제한',
      'matching_block' => '매칭 활동 제한',
      'chat_block' => '채팅 제한',
      'suspended' => '이용 정지',
      _ => '이용 제한',
    };
  }

  String get displayReason {
    final raw = reason.trim();
    if (raw.isEmpty) return '운영 정책 위반으로 제재가 적용되었습니다.';

    final normalized = raw.toLowerCase();
    if (normalized.startsWith('automated text moderation')) {
      if (normalized.contains('sexual_minors')) {
        return '미성년자와 관련된 부적절한 성적 표현이 감지되어 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('sexual_or_abusive_language')) {
        return '성적이거나 심각하게 부적절한 표현이 감지되어 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('explicit_abusive_language') ||
          normalized.contains('abusive_language')) {
        return '욕설 또는 모욕적인 표현이 감지되어 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('threatening_abuse')) {
        return '협박 또는 위협적인 표현이 감지되어 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('violent_language')) {
        return '폭력적인 표현이 감지되어 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('sexual')) {
        return '부적절한 성적 표현이 감지되어 자동 제재가 적용되었습니다.';
      }
      return '부적절한 표현이 감지되어 자동 제재가 적용되었습니다.';
    }

    if (normalized.startsWith('automated cancellation restriction')) {
      if (normalized.contains('repeated_general_matched_cancel_restricted')) {
        return '일반 매칭이 성사된 후 취소를 반복하여 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('general_matched_cancel_restricted')) {
        return '일반 매칭이 성사된 후 취소하여 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('completion_stage_cancel_restricted')) {
        return '작업 완료 단계에서 취소하여 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('late_matched_cancel_restricted')) {
        return '매칭이 성사된 뒤 늦게 취소하여 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('repeated_open_cancel_restricted')) {
        return '매칭 전 요청 취소를 짧은 시간 동안 반복하여 자동 제재가 적용되었습니다.';
      }
      if (normalized.contains('repeated_matched_cancel_restricted') ||
          normalized.contains('repeat_cancel_restricted')) {
        return '매칭 성사 후 취소를 반복하여 자동 제재가 적용되었습니다.';
      }
      return '취소가 반복되어 자동 제재가 적용되었습니다.';
    }

    if (normalized.startsWith('automated repeated post delete restriction')) {
      return '게시물 등록과 삭제를 짧은 시간 동안 반복하여 자동 제재가 적용되었습니다.';
    }

    if (normalized.startsWith('automated')) {
      return '서비스 이용 정책 위반이 감지되어 자동 제재가 적용되었습니다.';
    }

    return raw;
  }

  factory UserRestriction.fromMap(Map<String, dynamic> map) {
    return UserRestriction(
      id: map['id']?.toString() ?? '',
      type: map['restriction_type']?.toString() ?? 'warning',
      reason: map['reason']?.toString() ?? '',
      startsAt: _parseTs(map['starts_at']),
      endsAt: _parseTs(map['ends_at']),
      createdAt: _parseTs(map['created_at']),
    );
  }

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}

extension UserRestrictionListX on List<UserRestriction> {
  bool get hasAnyActive => isNotEmpty;
  bool get blocksRequest => any((item) => item.blocksRequest);
  bool get blocksWorker => any((item) => item.blocksWorker);
  bool get blocksChat => any((item) => item.blocksChat);
  bool get isSuspended => any((item) => item.isSuspended);

  UserRestriction? get mostSevere {
    if (isEmpty) return null;
    return reduce((a, b) => a.severityRank <= b.severityRank ? a : b);
  }
}
