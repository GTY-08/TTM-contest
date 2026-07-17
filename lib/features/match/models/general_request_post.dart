import 'match_request.dart';

class GeneralRequestPostImage {
  const GeneralRequestPostImage({
    required this.id,
    required this.requestId,
    required this.imageUrl,
    required this.storagePath,
    required this.sortOrder,
  });

  final String id;
  final String requestId;
  final String imageUrl;
  final String storagePath;
  final int sortOrder;

  factory GeneralRequestPostImage.fromMap(Map<String, dynamic> map) {
    return GeneralRequestPostImage(
      id: map['id']?.toString() ?? '',
      requestId: map['request_id']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toReplacePayload(int order) {
    return {
      'image_url': imageUrl,
      'storage_path': storagePath,
      'sort_order': order,
    };
  }
}

class UploadedGeneralPostImage {
  const UploadedGeneralPostImage({
    required this.imageUrl,
    required this.storagePath,
  });

  final String imageUrl;
  final String storagePath;

  Map<String, dynamic> toReplacePayload(int order) {
    return {
      'image_url': imageUrl,
      'storage_path': storagePath,
      'sort_order': order,
    };
  }
}

class GeneralRequestComment {
  const GeneralRequestComment({
    required this.id,
    required this.requestId,
    required this.authorId,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
    required this.authorNickname,
    this.authorProfileImageUrl,
  });

  final String id;
  final String requestId;
  final String authorId;
  final String content;
  final bool isDeleted;
  final DateTime createdAt;
  final String authorNickname;
  final String? authorProfileImageUrl;

  factory GeneralRequestComment.fromMap(Map<String, dynamic> map) {
    return GeneralRequestComment(
      id: map['id']?.toString() ?? '',
      requestId: map['request_id']?.toString() ?? '',
      authorId: map['author_id']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      isDeleted: map['is_deleted'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      authorNickname: map['author_nickname']?.toString() ?? '사용자',
      authorProfileImageUrl: map['author_profile_image_url']?.toString(),
    );
  }
}

class GeneralRequestPostDetail {
  const GeneralRequestPostDetail({
    required this.request,
    required this.images,
    required this.commentCount,
    required this.applicationCount,
    required this.requester,
    this.myApplicationId,
    this.myApplicationStatus,
  });

  final MatchRequest request;
  final List<GeneralRequestPostImage> images;
  final int commentCount;
  final int applicationCount;
  final Map<String, dynamic> requester;
  final String? myApplicationId;
  final String? myApplicationStatus;

  factory GeneralRequestPostDetail.fromMap(Map<String, dynamic> map) {
    final myApplication = map['my_application'];
    return GeneralRequestPostDetail(
      request: MatchRequest.fromMap(
        Map<String, dynamic>.from(map['request'] as Map),
      ),
      images: ((map['images'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => GeneralRequestPostImage.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
      applicationCount: (map['application_count'] as num?)?.toInt() ?? 0,
      requester: Map<String, dynamic>.from((map['requester'] as Map?) ?? {}),
      myApplicationId: myApplication is Map
          ? myApplication['application_id']?.toString()
          : null,
      myApplicationStatus: myApplication is Map
          ? myApplication['status']?.toString()
          : null,
    );
  }
}
