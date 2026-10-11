import 'package:flutter/foundation.dart';

import '../../../settings/domain/entities/user_settings.dart';

/// Community evaluation and comment model for an individual episode.
@immutable
class EpisodeReviewModel {
  const EpisodeReviewModel({
    required this.id,
    required this.episodeKeyString,
    required this.userId,
    required this.username,
    required this.userDisplayName,
    this.userAvatarId = 'tv_retro',
    this.userAvatarType = AvatarType.preset,
    this.userAvatarValue,
    this.rating,
    required this.comment,
    this.containsSpoilers = false,
    required this.createdAt,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.likedBy = const [],
    this.dislikedBy = const [],
  });

  final String id;

  /// Identifier pattern: "{seriesId}_s{seasonNumber}_e{episodeNumber}".
  final String episodeKeyString;
  final String userId;
  final String username;
  final String userDisplayName;
  final String userAvatarId;
  final AvatarType userAvatarType;
  final String? userAvatarValue;
  final double? rating;
  final String comment;
  final bool containsSpoilers;
  final DateTime createdAt;
  final int likesCount;
  final int dislikesCount;
  final List<String> likedBy;
  final List<String> dislikedBy;

  bool isLikedBy(String? uid) => uid != null && likedBy.contains(uid);
  bool isDislikedBy(String? uid) => uid != null && dislikedBy.contains(uid);

  static String buildKey(int seriesId, int seasonNumber, int episodeNumber) =>
      '${seriesId}_s${seasonNumber}_e$episodeNumber';

  factory EpisodeReviewModel.fromJson(Map<String, dynamic> json) {
    return EpisodeReviewModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      episodeKeyString: json['episodeKeyString'] as String? ?? '',
      userId: json['userId'] as String? ?? 'user',
      username: json['username'] as String? ?? 'membro',
      userDisplayName: json['userDisplayName'] as String? ?? 'Membro Seriolab',
      userAvatarId: json['userAvatarId'] as String? ?? 'tv_retro',
      userAvatarType: AvatarType.fromString(json['userAvatarType'] as String?),
      userAvatarValue: json['userAvatarValue'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      comment: json['comment'] as String? ?? '',
      containsSpoilers: json['containsSpoilers'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      dislikesCount: (json['dislikesCount'] as num?)?.toInt() ?? 0,
      likedBy: (json['likedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dislikedBy: (json['dislikedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'episodeKeyString': episodeKeyString,
        'userId': userId,
        'username': username,
        'userDisplayName': userDisplayName,
        'userAvatarId': userAvatarId,
        'userAvatarType': userAvatarType.name,
        'userAvatarValue': userAvatarValue,
        if (rating != null) 'rating': rating,
        'comment': comment,
        'containsSpoilers': containsSpoilers,
        'createdAt': createdAt.toIso8601String(),
        'likesCount': likesCount,
        'dislikesCount': dislikesCount,
        'likedBy': likedBy,
        'dislikedBy': dislikedBy,
      };

  EpisodeReviewModel copyWith({
    String? id,
    String? episodeKeyString,
    String? userId,
    String? username,
    String? userDisplayName,
    String? userAvatarId,
    AvatarType? userAvatarType,
    String? userAvatarValue,
    double? rating,
    String? comment,
    bool? containsSpoilers,
    DateTime? createdAt,
    int? likesCount,
    int? dislikesCount,
    List<String>? likedBy,
    List<String>? dislikedBy,
  }) =>
      EpisodeReviewModel(
        id: id ?? this.id,
        episodeKeyString: episodeKeyString ?? this.episodeKeyString,
        userId: userId ?? this.userId,
        username: username ?? this.username,
        userDisplayName: userDisplayName ?? this.userDisplayName,
        userAvatarId: userAvatarId ?? this.userAvatarId,
        userAvatarType: userAvatarType ?? this.userAvatarType,
        userAvatarValue: userAvatarValue ?? this.userAvatarValue,
        rating: rating ?? this.rating,
        comment: comment ?? this.comment,
        containsSpoilers: containsSpoilers ?? this.containsSpoilers,
        createdAt: createdAt ?? this.createdAt,
        likesCount: likesCount ?? this.likesCount,
        dislikesCount: dislikesCount ?? this.dislikesCount,
        likedBy: likedBy ?? this.likedBy,
        dislikedBy: dislikedBy ?? this.dislikedBy,
      );
}

/// Convenience alias matching user naming conventions
typedef EpisodeCommentModel = EpisodeReviewModel;
