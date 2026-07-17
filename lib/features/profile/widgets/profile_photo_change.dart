import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/app_user.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/repositories/profile_avatar_repository.dart';
import '../../profile/profile_copy.dart';

/// 프로필 탭에서 사진 변경: 갤러리/카메라 → 원형 크롭 → Storage 업로드.
class ProfilePhotoChangeHandler {
  ProfilePhotoChangeHandler._();

  static Future<void> start(
    BuildContext context,
    WidgetRef ref, {
    required AppUser user,
  }) async {
    if (!context.mounted) return;

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            TtmSpacing.lg,
            TtmSpacing.sm,
            TtmSpacing.lg,
            TtmSpacing.lg + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ProfileCopy.photoChange,
                style: TtmTypography.title.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: TtmSpacing.md),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('앨범에서 선택'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라로 촬영'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    final repo = ref.read(profileAvatarRepositoryProvider);
    try {
      final picked = await repo.pickImage(source);
      if (picked == null || !context.mounted) return;

      final cropped = await repo.cropToCircleAvatar(picked);
      if (cropped == null || !context.mounted) return;

      if (!context.mounted) return;
      await _uploadWithProgress(context, ref, repo, cropped);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('사진을 올리지 못했어요: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  static Future<void> _uploadWithProgress(
    BuildContext context,
    WidgetRef ref,
    ProfileAvatarRepository repo,
    File cropped,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(TtmSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: TtmColors.primary),
                SizedBox(height: TtmSpacing.md),
                Text('프로필 사진 업로드 중…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final url = await repo.uploadAvatarFile(cropped);
      await repo.saveProfileImageUrl(url);
      ref.invalidate(myProfileProvider);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('프로필 사진을 변경했어요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('업로드에 실패했어요: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }
}

/// 원형 프로필 아바타 (URL 없으면 기본 아이콘).
class TtmProfileAvatar extends StatelessWidget {
  const TtmProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 72,
    this.borderWidth = 0,
  });

  final String? imageUrl;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final hasBorder = borderWidth > 0;
    final image = ClipOval(
      child: SizedBox(
        width: size - (hasBorder ? borderWidth * 2 : 0),
        height: size - (hasBorder ? borderWidth * 2 : 0),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallbackIcon(size),
              )
            : _fallbackIcon(size),
      ),
    );

    if (!hasBorder) {
      return SizedBox(width: size, height: size, child: image);
    }

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: borderWidth,
          ),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Padding(padding: EdgeInsets.all(borderWidth), child: image),
      ),
    );
  }

  static Widget _fallbackIcon(double size) {
    return Icon(
      Icons.person,
      size: size * 0.5,
      color: TtmColors.primary.withValues(alpha: 0.7),
    );
  }
}
