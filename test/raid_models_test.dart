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

    test('never exposes a coordinate pair as an exercise place label', () {
      final venue = ExerciseVenue.fromMap({
        'id': 'venue-coordinate',
        'name': '35.8582, 128.6305',
        'address': '위도 35.8582 / 경도 128.6305',
        'latitude': 35.8582,
        'longitude': 128.6305,
      });

      expect(venue.name, '지도에서 선택한 운동 장소');
      expect(venue.address, '정확한 위치는 지도에서 확인해 주세요.');
      expect(isCoordinatePlaceText('35.8582, 128.6305'), isTrue);
      expect(isCoordinatePlaceText('대구광역시 수성구 청수로 257'), isFalse);
    });

    test('parses exercise-only profile activity counts', () {
      final summary = ExerciseActivitySummary.fromMap({
        'hosted_count': 2,
        'participated_count': 5,
      });

      expect(summary.hostedCount, 2);
      expect(summary.participatedCount, 5);
    });

    test('parses a fresh raid participant location', () {
      final capturedAt = DateTime.now().subtract(const Duration(seconds: 20));
      final location = RaidLiveLocation.fromMap({
        'raid_id': 'raid-1',
        'participant_id': 'participant-1',
        'user_id': 'user-1',
        'latitude': 35.8582,
        'longitude': 128.6305,
        'accuracy_m': 12.5,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      });

      expect(location.userId, 'user-1');
      expect(location.accuracyMeters, 12.5);
      expect(location.isFresh, isTrue);
    });

    test('parses a premium application chat context', () {
      final context = RaidApplicationChatContext.fromMap({
        'ok': true,
        'raid_id': 'raid-1',
        'raid_title': '주말 러닝',
        'raid_status': 'recruiting',
        'is_applicant': true,
        'participant': {
          'id': 'participant-1',
          'raid_id': 'raid-1',
          'user_id': 'applicant-1',
          'role': 'member',
          'status': 'applied',
          'application_message': '함께 뛰고 싶어요.',
        },
        'counterpart': {
          'id': 'organizer-1',
          'nickname': '운영자',
          'profile_image_url': 'https://example.com/profile.jpg',
          'is_premium': true,
        },
      });

      expect(context.isApplicant, isTrue);
      expect(context.isReadOnly, isFalse);
      expect(context.participant.applicationMessage, '함께 뛰고 싶어요.');
      expect(context.counterpart['nickname'], '운영자');
    });
  });
}
