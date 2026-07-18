import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/auth_providers.dart';
import '../../chat/models/chat_message.dart';
import '../models/exercise_matching_models.dart';
import '../models/raid_models.dart';
import '../repositories/raid_repository.dart';
import '../services/exercise_location_service.dart';

final raidRepositoryProvider = Provider<RaidRepository>((ref) {
  return RaidRepository(ref.watch(supabaseClientProvider));
});

final exerciseLocationServiceProvider = Provider<ExerciseLocationService>((
  ref,
) {
  return ExerciseLocationService();
});

final exerciseVenuesProvider = FutureProvider<List<ExerciseVenue>>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(raidRepositoryProvider).fetchVenues();
});

class RaidBrowseQuery {
  const RaidBrowseQuery({
    this.radiusMeters,
    this.exerciseType = 'all',
    this.feeType = 'all',
  });

  final int? radiusMeters;
  final String exerciseType;
  final String feeType;

  RaidBrowseQuery copyWith({
    int? radiusMeters,
    bool clearRadius = false,
    String? exerciseType,
    String? feeType,
  }) => RaidBrowseQuery(
    radiusMeters: clearRadius ? null : (radiusMeters ?? this.radiusMeters),
    exerciseType: exerciseType ?? this.exerciseType,
    feeType: feeType ?? this.feeType,
  );

  @override
  bool operator ==(Object other) =>
      other is RaidBrowseQuery &&
      other.radiusMeters == radiusMeters &&
      other.exerciseType == exerciseType &&
      other.feeType == feeType;

  @override
  int get hashCode => Object.hash(radiusMeters, exerciseType, feeType);
}

final raidBrowseQueryProvider = StateProvider<RaidBrowseQuery>(
  (ref) => const RaidBrowseQuery(),
);

final raidBrowseProvider = FutureProvider<List<Raid>>((ref) async {
  ref.watch(authUserIdProvider);
  final query = ref.watch(raidBrowseQueryProvider);
  ExerciseLocationSnapshot? location;
  try {
    location = await ref
        .watch(exerciseLocationServiceProvider)
        .current(request: query.radiusMeters != null);
  } on ExerciseLocationException {
    if (query.radiusMeters != null) rethrow;
  }
  return ref
      .watch(raidRepositoryProvider)
      .fetchRaids(
        latitude: location?.latitude,
        longitude: location?.longitude,
        radiusM: query.radiusMeters,
        exerciseType: query.exerciseType,
        feeType: query.feeType,
      );
});

class HomeRaidFeed {
  const HomeRaidFeed({required this.raids, required this.isNearby});
  final List<Raid> raids;
  final bool isNearby;
}

final nearbyRaidsProvider = FutureProvider<HomeRaidFeed>((ref) async {
  ref.watch(authUserIdProvider);
  ExerciseLocationSnapshot? location;
  try {
    location = await ref
        .watch(exerciseLocationServiceProvider)
        .current(request: false);
  } on ExerciseLocationException {
    location = null;
  }
  final raids = await ref
      .watch(raidRepositoryProvider)
      .fetchRaids(
        latitude: location?.latitude,
        longitude: location?.longitude,
        radiusM: location == null ? null : 5000,
        limit: 4,
      );
  return HomeRaidFeed(raids: raids, isNearby: location != null);
});

final myRaidsProvider = FutureProvider<List<Raid>>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(raidRepositoryProvider).fetchMyRaids();
});

final raidDetailProvider = FutureProvider.autoDispose
    .family<RaidDetail, String>(
      (ref, raidId) => ref.watch(raidRepositoryProvider).fetchDetail(raidId),
    );

final raidLocationsProvider = StreamProvider.autoDispose
    .family<List<RaidLiveLocation>, String>((ref, raidId) {
      ref.watch(authUserIdProvider);
      return ref.watch(raidRepositoryProvider).watchRaidLocations(raidId);
    });

final raidMessagesProvider = StreamProvider.autoDispose
    .family<
      ({List<ChatMessage> messages, Map<String, DateTime> reads}),
      String
    >((ref, raidId) {
      return ref.watch(raidRepositoryProvider).watchMessages(raidId);
    });

final raidApplicationMessagesProvider = StreamProvider.autoDispose
    .family<({List<ChatMessage> messages, ChatReadState reads}), String>((
      ref,
      participantId,
    ) {
      return ref
          .watch(raidRepositoryProvider)
          .watchApplicationMessages(participantId);
    });

final raidApplicationChatContextProvider = FutureProvider.autoDispose
    .family<RaidApplicationChatContext, String>((ref, participantId) {
      ref.watch(authUserIdProvider);
      return ref
          .watch(raidRepositoryProvider)
          .fetchApplicationChatContext(participantId);
    });

final exercisePreferencesProvider = FutureProvider<ExercisePreferences>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(raidRepositoryProvider).fetchExercisePreferences();
});

final myQuickMatchProvider = FutureProvider<ExerciseQuickMatch?>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(raidRepositoryProvider).fetchMyQuickMatch();
});

final quickMatchChatContextProvider = FutureProvider.autoDispose
    .family<ExerciseQuickMatch, String>((ref, quickMatchId) {
      ref.watch(authUserIdProvider);
      return ref
          .watch(raidRepositoryProvider)
          .fetchQuickMatchChatContext(quickMatchId);
    });

final exerciseMatchOffersProvider = FutureProvider<List<ExerciseMatchOffer>>((
  ref,
) {
  ref.watch(authUserIdProvider);
  return ref.watch(raidRepositoryProvider).fetchQuickMatchOffers();
});

final quickMatchMessagesProvider = StreamProvider.autoDispose
    .family<({List<ChatMessage> messages, ChatReadState reads}), String>((
      ref,
      quickMatchId,
    ) {
      return ref.watch(raidRepositoryProvider).watchQuickMessages(quickMatchId);
    });

final quickMatchLocationsProvider = StreamProvider.autoDispose
    .family<List<ExerciseQuickMatchLocation>, String>((ref, quickMatchId) {
      return ref
          .watch(raidRepositoryProvider)
          .watchQuickMatchLocations(quickMatchId);
    });

final raidRecruitmentProvider = FutureProvider.autoDispose
    .family<RaidRecruitmentCampaign?, String>((ref, raidId) {
      return ref.watch(raidRepositoryProvider).fetchRaidRecruitment(raidId);
    });

final raidRecruitmentOffersProvider =
    FutureProvider<List<RaidRecruitmentOffer>>((ref) {
      ref.watch(authUserIdProvider);
      return ref.watch(raidRepositoryProvider).fetchRaidRecruitmentOffers();
    });

final rewardSummaryProvider = FutureProvider<RewardSummary>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(raidRepositoryProvider).fetchRewardSummary();
});

final raidFeeWalletProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(raidRepositoryProvider).fetchFeeWallet();
});

void invalidateRaidData(Ref ref) {
  ref.invalidate(raidBrowseProvider);
  ref.invalidate(nearbyRaidsProvider);
  ref.invalidate(myRaidsProvider);
  ref.invalidate(myQuickMatchProvider);
  ref.invalidate(exerciseMatchOffersProvider);
  ref.invalidate(raidRecruitmentOffersProvider);
  ref.invalidate(rewardSummaryProvider);
  ref.invalidate(raidFeeWalletProvider);
}
