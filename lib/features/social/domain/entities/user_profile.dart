import '../../../settings/domain/entities/user_settings.dart';

/// Represents a public or local user profile in the Seriolab social system.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarId = 'tv_retro',
    this.avatarType = AvatarType.preset,
    this.avatarValue,
    this.profileBannerUrl,
    this.profileBannerPath,
    this.followersCount = 0,
    this.followingCount = 0,
    this.topFiveFavorites = const [],
    this.followers = const [],
    this.following = const [],
    this.recentRatings = const [],
    this.isCurrentUser = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String avatarId;
  final AvatarType avatarType;
  final String? avatarValue;
  final String? profileBannerUrl;
  final String? profileBannerPath;
  final int followersCount;
  final int followingCount;
  final List<int> topFiveFavorites;
  final List<String> followers;
  final List<String> following;
  final List<UserShowRating> recentRatings;
  final bool isCurrentUser;

  String get effectiveAvatarValue => avatarValue ?? avatarId;

  String get handle => username.startsWith('@') ? username : '@$username';

  bool get hasCustomBanner =>
      (profileBannerUrl != null && profileBannerUrl!.trim().isNotEmpty) ||
      (profileBannerPath != null && profileBannerPath!.trim().isNotEmpty);

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? bio,
    String? avatarId,
    AvatarType? avatarType,
    String? avatarValue,
    String? profileBannerUrl,
    String? profileBannerPath,
    int? followersCount,
    int? followingCount,
    List<int>? topFiveFavorites,
    List<String>? followers,
    List<String>? following,
    List<UserShowRating>? recentRatings,
    bool? isCurrentUser,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarId: avatarId ?? this.avatarId,
      avatarType: avatarType ?? this.avatarType,
      avatarValue: avatarValue ?? this.avatarValue,
      profileBannerUrl: profileBannerUrl ?? this.profileBannerUrl,
      profileBannerPath: profileBannerPath ?? this.profileBannerPath,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      topFiveFavorites: topFiveFavorites ?? this.topFiveFavorites,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      recentRatings: recentRatings ?? this.recentRatings,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatarId': avatarId,
      'avatarType': avatarType.name,
      'avatarValue': avatarValue,
      'profileBannerUrl': profileBannerUrl,
      'profileBannerPath': profileBannerPath,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'topFiveFavorites': topFiveFavorites,
      'followers': followers,
      'following': following,
      'recentRatings': recentRatings.map((r) => r.toJson()).toList(),
      'isCurrentUser': isCurrentUser,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final avatarType = AvatarType.fromString(json['avatarType'] as String?);
    final avatarId = json['avatarId'] as String? ?? 'tv_retro';

    List<int> parseShowIds(dynamic raw) {
      if (raw is List) {
        return raw.whereType<num>().map((e) => e.toInt()).toList();
      }
      return const [];
    }

    List<String> parseStrings(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }

    List<UserShowRating> parseRatings(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(UserShowRating.fromJson)
            .toList();
      }
      return const [];
    }

    final followersList = parseStrings(json['followers']);
    final followingList = parseStrings(json['following']);

    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarId: avatarId,
      avatarType: avatarType,
      avatarValue: json['avatarValue'] as String?,
      profileBannerUrl: json['profileBannerUrl'] as String?,
      profileBannerPath: json['profileBannerPath'] as String?,
      followersCount:
          json['followersCount'] as int? ?? followersList.length,
      followingCount:
          json['followingCount'] as int? ?? followingList.length,
      topFiveFavorites: parseShowIds(json['topFiveFavorites']),
      followers: followersList,
      following: followingList,
      recentRatings: parseRatings(json['recentRatings']),
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  /// Creates a [UserProfile] representation from [UserSettings].
  factory UserProfile.fromUserSettings(UserSettings settings, {String uid = 'current_user'}) {
    return UserProfile(
      id: uid,
      username: settings.username,
      displayName: settings.displayName,
      bio: settings.bio,
      avatarId: settings.avatarId,
      avatarType: settings.avatarType,
      avatarValue: settings.avatarValue,
      profileBannerUrl: settings.profileBannerUrl,
      profileBannerPath: settings.profileBannerPath,
      followersCount: settings.followers.length,
      followingCount: settings.following.length,
      topFiveFavorites: settings.favoriteShowIds,
      followers: settings.followers,
      following: settings.following,
      recentRatings: const [],
      isCurrentUser: true,
    );
  }
}

/// A show rating entry shown on a user's profile activity.
class UserShowRating {
  const UserShowRating({
    required this.showId,
    required this.showTitle,
    this.posterUrl,
    required this.rating,
    required this.ratedAt,
  });

  final int showId;
  final String showTitle;
  final String? posterUrl;
  final double rating;
  final DateTime ratedAt;

  Map<String, dynamic> toJson() {
    return {
      'showId': showId,
      'showTitle': showTitle,
      'posterUrl': posterUrl,
      'rating': rating,
      'ratedAt': ratedAt.toIso8601String(),
    };
  }

  factory UserShowRating.fromJson(Map<String, dynamic> json) {
    return UserShowRating(
      showId: json['showId'] as int? ?? 0,
      showTitle: json['showTitle'] as String? ?? '',
      posterUrl: json['posterUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratedAt: json['ratedAt'] != null
          ? DateTime.tryParse(json['ratedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
