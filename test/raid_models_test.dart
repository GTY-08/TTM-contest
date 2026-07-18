import 'package:flutter_test/flutter_test.dart';
import 'package:ttm_app/features/raid/models/raid_models.dart';

void main() {
  group('Raid models', () {
    test('parses a raid with venue and participant state', () {
      final raid = Raid.fromMap({
        'id': 'raid-1',
        'source': 'premium',
        'organizer_id': 'host-1',
        'exercise_type': 'running',
        'title': '퇴근 후 러닝',
        'description': '가볍게 함께 달려요.',
        'starts_at': '2030-01-01T09:00:00Z',
        'duration_minutes': 70,
        'min_participants': 3,
        'max_participants': 8,
        'participant_count': 4,
        'intensity': 'medium',
        'beginner_friendly': true,
        'participation_fee': 1000,
        'distance_m': 1450,
        'status': 'recruiting',
        'venue': {
          'id': 'venue-1',
          'name': '시민 운동장',
          'address': '서울시 성동구',
          'latitude': 37.55,
          'longitude': 127.04,
          'supported_exercises': ['running', 'walking'],
        },
        'my_participant': {
          'id': 'participant-1',
          'user_id': 'user-1',
          'role': 'member',
          'status': 'applied',
          'payment_status': 'payment_pending',
          'attendance_status': 'pending',
        },
      });

      expect(raid.id, 'raid-1');
      expect(raid.venue.name, '시민 운동장');
      expect(raid.participantCount, 4);
      expect(raid.distanceMeters, 1450);
      expect(raid.isPremiumRaid, isTrue);
      expect(raid.isApplied, isTrue);
      expect(raid.isMember, isFalse);
      expect(raid.endsAt.difference(raid.startsAt).inMinutes, 70);
    });

    test('only system-created raids use instant participation', () {
      Raid raidFor(String source) => Raid.fromMap({
        'id': 'raid-$source',
        'source': source,
        'exercise_type': 'running',
        'title': 'Morning run',
        'starts_at': '2030-01-01T09:00:00Z',
        'participation_fee': 0,
        'venue': {
          'id': 'venue-1',
          'name': 'Park',
          'latitude': 37.55,
          'longitude': 127.04,
        },
      });

      expect(raidFor('auto').isFree, isTrue);
      expect(raidFor('premium').isFree, isFalse);
    });

    test('clamps reward level progress between zero and one', () {
      RewardSummary summary(int lifetime) => RewardSummary(
        availablePoints: 100,
        lifetimePoints: lifetime,
        level: 2,
        levelTitle: '꾸준한 시작',
        requiredPoints: 500,
        nextRequiredPoints: 1500,
        catalog: const [],
        transactions: const [],
        redemptions: const [],
      );

      expect(summary(250).levelProgress, 0);
      expect(summary(1000).levelProgress, 0.5);
      expect(summary(2000).levelProgress, 1);
    });

    test('uses Korean labels for known activity states', () {
      expect(exerciseLabel('running'), '러닝');
      expect(intensityLabel('high'), '높음');
      expect(raidStatusLabel('completed'), '완료');
    });

    test('parses a place search result for map navigation', () {
      final place = RaidPlaceSearchResult.fromMap({
        'name': '두류공원',
        'roadAddress': '대구광역시 달서구 공원순환로 36',
        'source': 'local',
        'lat': 35.8501,
        'lng': 128.5584,
      });

      expect(place.label, '두류공원');
      expect(place.address, '대구광역시 달서구 공원순환로 36');
      expect(place.hasValidLocation, isTrue);
    });
  });
}
