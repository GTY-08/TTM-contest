import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_user.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/repositories/chat_attachment_repository.dart';
import '../repositories/chat_repository.dart';

final chatAttachmentRepositoryProvider = Provider<ChatAttachmentRepository>((
  ref,
) {
  return ChatAttachmentRepository(ref.watch(supabaseClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(supabaseClientProvider),
    attachments: ref.watch(chatAttachmentRepositoryProvider),
  );
});

final messagesStreamProvider =
    StreamProvider.family<
      ({List<ChatMessage> messages, ChatReadState reads}),
      String
    >((ref, requestId) {
      return ref
          .watch(chatRepositoryProvider)
          .watchMessagesWithReads(requestId);
    });

/// 매칭 상대 프로필 (닉네임·사진).
final matchCounterpartProvider =
    FutureProvider.family<AppUser?, ({String requestId, String counterpartId})>(
      (ref, args) async {
        if (args.counterpartId.isEmpty) return null;
        return ref
            .read(userRepositoryProvider)
            .fetchMatchCounterpartProfile(args.requestId);
      },
    );
