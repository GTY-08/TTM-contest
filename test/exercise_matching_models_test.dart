import 'package:flutter_test/flutter_test.dart';
import 'package:ttm_app/features/raid/models/exercise_matching_models.dart';
import 'package:ttm_app/features/raid/services/exercise_location_service.dart';

void main() {
  group('Exercise matching models', () {
    test('parses quick match state and partner data', () {
      final match = ExerciseQuickMatch.fromMap({
        'id': 'quick-1',
        'requester_id': 'user-1',
        'matched_user_id': 'user-2',
        'meeting_source': 'venue',
        'meeting_venue_id': 'venue-1',
        'meeting_label': '시민 운동장',
        'exercise_type': 'running',
        'duration_minutes': 60,
        'intensity': 'medium',
        'partner_level_pref': 'similar',
        'max_distance_m': 3000,
        'starts_at': '2030-01-01T09:00:00Z',
        'ends_at': '2030-01-01T10:00:00Z',
        'status': 'matched',
        'current_stage': 4,
        'expires_at': '2030-01-01T09:01:20Z',
        'partner': {'id': 'user-2', 'nickname': '운동친구'},
      });

      expect(match.isMatched, isTrue);
      expect(match.isSearching, isFalse);
      expect(match.durationMinutes, 60);
      expect(match.partner?['nickname'], '운동친구');
    });

    test('parses exercise preferences defaults and values', () {
      final preferences = ExercisePreferences.fromMap({
        'activity_label': '현재 위치 주변',
        'latitude': 37.55,
        'longitude': 127.04,
        'preferred_exercises': ['walking', 'running'],
        'fitness_level': 'intermediate',
        'available_days': [1, 3, 5],
        'available_start': '18:00:00',
        'available_end': '22:00:00',
        'max_distance_m': 5000,
      });

      expect(preferences.preferredExercises, ['walking', 'running']);
      expect(preferences.availableDays, [1, 3, 5]);
      expect(preferences.maxDistanceMeters, 5000);
    });

    test('maps distance validation failures to user-facing Korean copy', () {
      expect(exerciseLocationMessage('outside_raid_range'), contains('5km'));
      expect(exerciseLocationMessage('schedule_conflict'), contains('시간이 겹쳐요'));
    });
  });
}
