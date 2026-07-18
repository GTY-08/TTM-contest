import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/storage_constants.dart';

/// 매칭 DM 이미지 — `chat_attachments/{requestId}/{userId}/{ts}.ext`
class ChatAttachmentRepository {
  ChatAttachmentRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<String> uploadChatImage({
    required String requestId,
    required File file,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final bytes = await file.readAsBytes();
    final lower = file.path.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        '$requestId/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    return _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .getPublicUrl(path);
  }

  Future<String> uploadGeneralApplicationImage({
    required String applicationId,
    required File file,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final bytes = await file.readAsBytes();
    final lower = file.path.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        'application/$applicationId/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    return _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .getPublicUrl(path);
  }

  Future<String> uploadRaidApplicationImage({
    required String participantId,
    required File file,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final bytes = await file.readAsBytes();
    final lower = file.path.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        'raid-application/$participantId/$uid/'
        '${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    return _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .getPublicUrl(path);
  }

  Future<String> uploadExerciseQuickMatchImage({
    required String quickMatchId,
    required File file,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final bytes = await file.readAsBytes();
    final lower = file.path.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        'quick-match/$quickMatchId/$uid/'
        '${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    return _supabase.storage
        .from(TtmStorageConstants.chatAttachmentsBucket)
        .getPublicUrl(path);
  }

  Future<String> uploadTaskProofImage({
    required String requestId,
    required File file,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final bytes = await file.readAsBytes();
    final lower = file.path.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
        ? 'webp'
        : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        '$requestId/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from(TtmStorageConstants.taskProofsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    return path;
  }
}
