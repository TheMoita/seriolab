import 'dart:convert';

import '../../../auth/domain/services/auth_service.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../tracking/domain/repositories/tracking_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/social_repository.dart';

/// Implementation of [SocialRepository] using local persistence
/// with [SettingsRepository] and [TrackingRepository].
class SocialRepositoryImpl implements SocialRepository {
  SocialRepositoryImpl({
    required this.settingsRepo,
    required this.trackingRepo,
    this.authService,
  });

  final SettingsRepository settingsRepo;
  final TrackingRepository trackingRepo;
  final AuthService? authService;

  SettingsRepository get _settingsRepo => settingsRepo;
  TrackingRepository get _trackingRepo => trackingRepo;
  AuthService? get _authService => authService;

  static const _socialUsersMetaKey = 'seriolab_social_users_state';
  static const _currentUserId = 'me';

  String get _activeUserId => _authService?.currentUser?.uid ?? _currentUserId;

  /// Default curated community profiles for discovery and social interaction.
  static final List<UserProfile> _defaultCommunityProfiles = [
    UserProfile(
      id: 'user_marta',
      username: 'martas',
      displayName: 'Marta Silva',
      bio: 'Cineasta e viciada em Breaking Bad, Succession e Severance.',
      avatarId: 'cinema_popcorn',
      avatarType: AvatarType.preset,
      profileBannerUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=1200&auto=format&fit=crop',
      followersCount: 142,
      followingCount: 38,
      topFiveFavorites: [1396, 76479, 1399, 94605, 87108], // Breaking Bad, Succession, GOT, Arcane, Chernobyl
      recentRatings: [
        UserShowRating(
          showId: 1396,
          showTitle: 'Breaking Bad',
          rating: 10.0,
          ratedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        UserShowRating(
          showId: 76479,
          showTitle: 'Succession',
          rating: 9.5,
          ratedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        UserShowRating(
          showId: 94605,
          showTitle: 'Arcane',
          rating: 9.0,
          ratedAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ],
    ),
    UserProfile(
      id: 'user_diogo',
      username: 'diogof',
      displayName: 'Diogo Ferreira',
      bio: 'Ficção científica e séries nórdicas. The Expanse, Dark e Severance no coração.',
      avatarId: 'tv_retro',
      avatarType: AvatarType.preset,
      profileBannerUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1200&auto=format&fit=crop',
      followersCount: 98,
      followingCount: 55,
      topFiveFavorites: [63247, 70523, 60625, 4614, 119051], // Westworld, Dark, Rick and Morty, NCIS, Wednesday
      recentRatings: [
        UserShowRating(
          showId: 70523,
          showTitle: 'Dark',
          rating: 10.0,
          ratedAt: DateTime.now().subtract(const Duration(hours: 12)),
        ),
        UserShowRating(
          showId: 63247,
          showTitle: 'Westworld',
          rating: 8.5,
          ratedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ],
    ),
    UserProfile(
      id: 'user_beatriz',
      username: 'bealima',
      displayName: 'Beatriz Lima',
      bio: 'Anime, fantasia e comédia britânica. Fleabag é a melhor série de sempre.',
      avatarId: 'sparkles',
      avatarType: AvatarType.preset,
      profileBannerUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?q=80&w=1200&auto=format&fit=crop',
      followersCount: 215,
      followingCount: 120,
      topFiveFavorites: [85937, 65930, 42009, 60059, 1429], // Demon Slayer, Fleabag, Peaky Blinders, Better Call Saul, Attack on Titan
      recentRatings: [
        UserShowRating(
          showId: 65930,
          showTitle: 'Fleabag',
          rating: 10.0,
          ratedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        UserShowRating(
          showId: 85937,
          showTitle: 'Demon Slayer',
          rating: 9.0,
          ratedAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
      ],
    ),
    UserProfile(
      id: 'user_tiago',
      username: 'tiagocine',
      displayName: 'Tiago Ramos',
      bio: 'Crítico de televisão e séries dramáticas. Better Call Saul > Breaking Bad.',
      avatarId: 'film_roll',
      avatarType: AvatarType.preset,
      profileBannerUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1200&auto=format&fit=crop',
      followersCount: 350,
      followingCount: 80,
      topFiveFavorites: [60059, 1396, 94605, 76479, 87108],
      recentRatings: [
        UserShowRating(
          showId: 60059,
          showTitle: 'Better Call Saul',
          rating: 10.0,
          ratedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    ),
    UserProfile(
      id: 'user_sofia',
      username: 'sofiaseries',
      displayName: 'Sofia Martins',
      bio: 'A maratonar uma série nova todas as semanas. Aberta a recomendações!',
      avatarId: 'tv_modern',
      avatarType: AvatarType.preset,
      profileBannerUrl:
          'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?q=80&w=1200&auto=format&fit=crop',
      followersCount: 77,
      followingCount: 43,
      topFiveFavorites: [119051, 63247, 70523, 1399, 65930],
      recentRatings: [
        UserShowRating(
          showId: 119051,
          showTitle: 'Wednesday',
          rating: 8.5,
          ratedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
    ),
    UserProfile(
      id: 'user_andre',
      username: 'andre_silva',
      displayName: 'André Silva',
      bio: 'Fã incondicional de sitcoms clássicos e comfort shows.',
      avatarId: 'couch_potato',
      avatarType: AvatarType.preset,
      profileBannerUrl:
          'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?q=80&w=1200&auto=format&fit=crop',
      followersCount: 53,
      followingCount: 62,
      topFiveFavorites: [1668, 1429, 1100, 2382, 1408], // Friends, Attack on Titan, The Office, etc.
      recentRatings: [
        UserShowRating(
          showId: 1668,
          showTitle: 'Friends',
          rating: 9.0,
          ratedAt: DateTime.now().subtract(const Duration(days: 6)),
        ),
      ],
    ),
  ];

  /// Loads all stored community user profiles with any persisted follower changes.
  Future<Map<String, UserProfile>> _loadAllProfiles() async {
    final map = <String, UserProfile>{};
    for (final p in _defaultCommunityProfiles) {
      map[p.id] = p;
    }

    try {
      final raw = await _trackingRepo.readMeta(_socialUsersMetaKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            final p = UserProfile.fromJson(entry.value as Map<String, dynamic>);
            map[p.id] = p;
          }
        }
      }
    } catch (_) {}

    return map;
  }

  Future<void> _saveAllProfiles(Map<String, UserProfile> profiles) async {
    final jsonMap = profiles.map((k, v) => MapEntry(k, v.toJson()));
    await _trackingRepo.writeMeta(_socialUsersMetaKey, jsonEncode(jsonMap));
  }

  @override
  Future<void> followUser(String targetUserId) async {
    final settings = await _settingsRepo.getSettings();
    final following = List<String>.from(settings.following);
    if (!following.contains(targetUserId)) {
      following.add(targetUserId);
      await _settingsRepo.saveSettings(settings.copyWith(following: following));
    }

    final profiles = await _loadAllProfiles();
    final target = profiles[targetUserId];
    if (target != null) {
      final followers = List<String>.from(target.followers);
      if (!followers.contains(_activeUserId)) {
        followers.add(_activeUserId);
      }
      profiles[targetUserId] = target.copyWith(
        followersCount: target.followersCount + 1,
        followers: followers,
      );
      await _saveAllProfiles(profiles);
    }
  }

  @override
  Future<void> unfollowUser(String targetUserId) async {
    final settings = await _settingsRepo.getSettings();
    final following = List<String>.from(settings.following);
    if (following.contains(targetUserId)) {
      following.remove(targetUserId);
      await _settingsRepo.saveSettings(settings.copyWith(following: following));
    }

    final profiles = await _loadAllProfiles();
    final target = profiles[targetUserId];
    if (target != null) {
      final followers = List<String>.from(target.followers)..remove(_activeUserId);
      final newCount = (target.followersCount - 1).clamp(0, 999999);
      profiles[targetUserId] = target.copyWith(
        followersCount: newCount,
        followers: followers,
      );
      await _saveAllProfiles(profiles);
    }
  }

  @override
  Future<bool> isFollowing(String targetUserId) async {
    final settings = await _settingsRepo.getSettings();
    return settings.following.contains(targetUserId);
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    final settings = await _settingsRepo.getSettings();
    final isMe = userId == _activeUserId ||
        userId == 'me' ||
        userId == 'current_user' ||
        userId.toLowerCase() == settings.username.toLowerCase();

    if (isMe) {
      return UserProfile.fromUserSettings(settings, uid: _activeUserId);
    }

    final profiles = await _loadAllProfiles();
    var profile = profiles[userId];
    if (profile == null) {
      // Try search by username
      final clean = userId.replaceFirst('@', '').toLowerCase();
      profile = profiles.values.cast<UserProfile?>().firstWhere(
            (p) => p?.username.toLowerCase() == clean,
            orElse: () => null,
          );
    }

    if (profile != null) {
      final isCurrentlyFollowing = settings.following.contains(profile.id);
      final hasIdInFollowers = profile.followers.contains(_activeUserId);

      // Harmonize follower count with user's actual following state
      var dynamicFollowersCount = profile.followersCount;
      if (isCurrentlyFollowing && !hasIdInFollowers) {
        dynamicFollowersCount += 1;
      }

      return profile.copyWith(
        followersCount: dynamicFollowersCount,
      );
    }

    return null;
  }

  @override
  Future<List<UserProfile>> getFollowers(String userId) async {
    final settings = await _settingsRepo.getSettings();
    final isMe = userId == _activeUserId ||
        userId == 'me' ||
        userId == 'current_user' ||
        userId.toLowerCase() == settings.username.toLowerCase();

    final profiles = await _loadAllProfiles();

    if (isMe) {
      final result = <UserProfile>[];
      for (final fid in settings.followers) {
        final p = profiles[fid];
        if (p != null) result.add(p);
      }
      return result;
    }

    final target = profiles[userId];
    if (target != null) {
      final result = <UserProfile>[];
      for (final fid in target.followers) {
        if (fid == _activeUserId) {
          result.add(UserProfile.fromUserSettings(settings, uid: _activeUserId));
        } else {
          final p = profiles[fid];
          if (p != null) result.add(p);
        }
      }
      return result;
    }

    return [];
  }

  @override
  Future<List<UserProfile>> getFollowing(String userId) async {
    final settings = await _settingsRepo.getSettings();
    final isMe = userId == _activeUserId ||
        userId == 'me' ||
        userId == 'current_user' ||
        userId.toLowerCase() == settings.username.toLowerCase();

    final profiles = await _loadAllProfiles();

    if (isMe) {
      final result = <UserProfile>[];
      for (final fid in settings.following) {
        final p = profiles[fid];
        if (p != null) {
          result.add(p);
        }
      }
      return result;
    }

    final target = profiles[userId];
    if (target != null) {
      final result = <UserProfile>[];
      for (final fid in target.following) {
        final p = profiles[fid];
        if (p != null) result.add(p);
      }
      return result;
    }

    return [];
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    final clean = query.trim().replaceFirst('@', '').toLowerCase();
    if (clean.isEmpty) return [];

    final profiles = await _loadAllProfiles();
    final currentSettings = await _settingsRepo.getSettings();

    final matches = profiles.values.where((p) {
      final u = p.username.toLowerCase();
      final n = p.displayName.toLowerCase();
      return u.contains(clean) || n.contains(clean);
    }).toList();

    // If query matches current user
    if (currentSettings.username.toLowerCase().contains(clean) ||
        currentSettings.displayName.toLowerCase().contains(clean)) {
      matches.insert(0, UserProfile.fromUserSettings(currentSettings, uid: _activeUserId));
    }

    return matches;
  }

  @override
  Future<List<UserProfile>> getSuggestedUsers() async {
    final profiles = await _loadAllProfiles();
    final settings = await _settingsRepo.getSettings();

    // Filter out already followed users and current user
    final suggestions = profiles.values.where((p) {
      return !settings.following.contains(p.id) && p.id != _activeUserId;
    }).toList();

    return suggestions;
  }
}
