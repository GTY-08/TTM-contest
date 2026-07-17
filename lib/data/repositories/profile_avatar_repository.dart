import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/storage_constants.dart';
import '../../core/theme/app_colors.dart';
import '../models/app_user.dart';

/// 갤러리/카메라 → 크롭 → Storage 업로드 → users.profile_image_url 갱신.
class ProfileAvatarRepository {
  ProfileAvatarRepository(this._supabase);

  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<File?> cropToCircleAvatar(File source) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: source.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '프로필 범위',
          toolbarColor: TtmColors.primary,
          toolbarWidgetColor: Colors.white,
          statusBarLight: false,
          navBarLight: true,
          backgroundColor: const Color(0xFFF8F7F4),
          activeControlsWidgetColor: TtmColors.primary,
          dimmedLayerColor: Colors.black.withValues(alpha: 0.55),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: '프로필 범위',
          aspectRatioLockEnabled: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }

  /// 크롭된 JPEG 를 `{uid}/avatar.jpg` 로 upsert 하고 공개 URL 을 반환한다.
  Future<String> uploadAvatarFile(File file) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final bytes = await file.readAsBytes();
    final path = '$uid/${TtmStorageConstants.avatarFileName}';

    await _supabase.storage
        .from(TtmStorageConstants.avatarsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final baseUrl = _supabase.storage
        .from(TtmStorageConstants.avatarsBucket)
        .getPublicUrl(path);
    // CDN 캐시 갱신용 쿼리 (같은 경로 upsert 시 UI 즉시 반영)
    final bust = DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl?v=$bust';
  }

  Future<AppUser> saveProfileImageUrl(String profileImageUrl) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not_authenticated');

    final row = await _supabase
        .from('users')
        .update({'profile_image_url': profileImageUrl})
        .eq('id', uid)
        .select()
        .single();

    return AppUser.fromMap(row);
  }
}
