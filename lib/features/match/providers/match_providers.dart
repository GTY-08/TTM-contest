import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/auth_providers.dart';
import '../../../data/models/app_user.dart';
import '../../chat/models/chat_message.dart';
import '../models/general_request_applicant.dart';
import '../models/general_request_post.dart';
import '../models/match_request.dart';
import '../models/worker_notification.dart';
import '../models/request_task_proof.dart';
import '../repositories/matching_repository.dart';

/// 매칭 도메인 전용 Repository.
final matchingRepositoryProvider = Provider<MatchingRepository>((ref) {
  return MatchingRepository(ref.watch(supabaseClientProvider));
});

/// 한 요청의 변경을 Realtime 으로 구독.
final requestStreamProvider = StreamProvider.family<MatchRequest?, String>((
  ref,
  requestId,
) {
  return ref.watch(matchingRepositoryProvider).watchRequest(requestId);
});

final taskProofsProvider = StreamProvider.autoDispose
    .family<List<RequestTaskProof>, String>((ref, requestId) {
      return ref.watch(matchingRepositoryProvider).watchTaskProofs(requestId);
    });

/// 현재 로그인한 작업자에게 도착해 있는 pending 알림 + 요청 본문.
final myPendingNotificationsProvider = StreamProvider<List<WorkerNotification>>(
  (ref) {
    final uid = ref.watch(authUserIdProvider);
    if (uid == null) {
      return const Stream<List<WorkerNotification>>.empty();
    }
    return ref
        .watch(matchingRepositoryProvider)
        .watchMyPendingNotifications(uid);
  },
);

/// 본인이 요청자·작업자로 참여 중인 matched 심부름.
final myActiveMatchedRequestsProvider = StreamProvider<List<MatchRequest>>((
  ref,
) {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) {
    return const Stream<List<MatchRequest>>.empty();
  }
  return ref
      .watch(matchingRepositoryProvider)
      .watchMyActiveMatchedRequests(uid);
});

final myCompletedWorkRequestsProvider = FutureProvider<List<MatchRequest>>((
  ref,
) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return const [];
  return ref.read(matchingRepositoryProvider).fetchMyCompletedWorkRequests(uid);
});

final myCompletedRequestedRequestsProvider = FutureProvider<List<MatchRequest>>(
  (ref) async {
    final uid = ref.watch(authUserIdProvider);
    if (uid == null) return const [];
    return ref
        .read(matchingRepositoryProvider)
        .fetchMyCompletedRequestedRequests(uid);
  },
);

final myCompletedRequestsStreamProvider = StreamProvider<List<MatchRequest>>((
  ref,
) {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) {
    return const Stream<List<MatchRequest>>.empty();
  }
  return ref.watch(matchingRepositoryProvider).watchMyCompletedRequests(uid);
});

final myOpenGeneralRequestsProvider = FutureProvider<List<MatchRequest>>((
  ref,
) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return const [];
  return ref.read(matchingRepositoryProvider).fetchMyOpenGeneralRequests(uid);
});

final myGeneralApplicationsProvider =
    FutureProvider<List<GeneralRequestApplicationSummary>>((ref) async {
      final uid = ref.watch(authUserIdProvider);
      if (uid == null) return const [];
      return ref
          .read(matchingRepositoryProvider)
          .fetchMyGeneralRequestApplications(uid);
    });

final generalApplicationCounterpartProvider = FutureProvider.autoDispose
    .family<AppUser?, String>((ref, applicationId) async {
      final uid = ref.watch(authUserIdProvider);
      if (uid == null) return null;
      return ref
          .read(matchingRepositoryProvider)
          .fetchGeneralApplicationCounterpartProfile(applicationId);
    });

final generalApplicationAgreementProvider = StreamProvider.autoDispose
    .family<GeneralApplicationAgreement?, String>((ref, applicationId) {
      return ref
          .watch(matchingRepositoryProvider)
          .watchGeneralApplicationAgreement(applicationId);
    });

final generalRequestApplicantsProvider = StreamProvider.autoDispose
    .family<List<GeneralRequestApplicant>, String>((ref, requestId) async* {
      ref.watch(requestStreamProvider(requestId));
      final repo = ref.watch(matchingRepositoryProvider);
      Future<List<GeneralRequestApplicant>> load() =>
          repo.listGeneralRequestApplicants(requestId);

      yield await load();
      await for (final _ in repo.watchGeneralRequestApplications(requestId)) {
        yield await load();
      }
    });

final generalRequestDetailProvider = FutureProvider.autoDispose
    .family<GeneralRequestPostDetail, String>((ref, requestId) {
      ref.watch(requestStreamProvider(requestId));
      return ref
          .read(matchingRepositoryProvider)
          .fetchGeneralRequestDetail(requestId);
    });

final generalRequestCommentsProvider = FutureProvider.autoDispose
    .family<List<GeneralRequestComment>, String>((ref, requestId) {
      ref.watch(requestStreamProvider(requestId));
      return ref
          .read(matchingRepositoryProvider)
          .fetchGeneralRequestComments(requestId);
    });

final recommendedGeneralRequestsProvider = FutureProvider.autoDispose
    .family<List<WorkerNotification>, String>((ref, requestId) async {
      final uid = ref.watch(authUserIdProvider);
      if (uid == null) return const [];
      final detail = await ref.watch(
        generalRequestDetailProvider(requestId).future,
      );
      final applications = await ref.watch(
        myGeneralApplicationsProvider.future,
      );
      final ownPosts = await ref.watch(myOpenGeneralRequestsProvider.future);
      final affinityRequests = <MatchRequest>[
        for (final item in applications) item.request,
        ...ownPosts,
      ];
      return ref
          .read(matchingRepositoryProvider)
          .fetchRecommendedGeneralRequests(
            workerId: uid,
            current: detail.request,
            affinityRequests: affinityRequests,
          );
    });

final generalApplicationMessagesProvider = StreamProvider.autoDispose
    .family<({List<ChatMessage> messages, ChatReadState reads}), String>((
      ref,
      applicationId,
    ) {
      return ref
          .watch(matchingRepositoryProvider)
          .watchGeneralApplicationMessagesWithReads(applicationId);
    });
