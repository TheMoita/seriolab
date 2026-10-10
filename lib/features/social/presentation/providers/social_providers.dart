import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/repositories/social_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/social_repository.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  final authService = ref.watch(authServiceProvider);

  return SocialRepositoryImpl(
    settingsRepo: settingsRepo,
    trackingRepo: trackingRepo,
    authService: authService,
  );
});

/// Returns whether the logged in user is following [userId].
final isFollowingUserProvider = Provider.family<bool, String>((ref, userId) {
  final settings = ref.watch(settingsControllerProvider);
  return settings.following.contains(userId);
});

/// Fetches the profile of a given user by [userId].
final userProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.getUserProfile(userId);
});

/// Fetches the followers of a given user by [userId].
final userFollowersProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.getFollowers(userId);
});

/// Fetches the following list of a given user by [userId].
final userFollowingProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.getFollowing(userId);
});

/// Suggests community users to follow.
final suggestedUsersProvider =
    FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(socialRepositoryProvider);
  // Re-fetch when following list changes in settings
  ref.watch(settingsControllerProvider.select((s) => s.following));
  return repo.getSuggestedUsers();
});

/// Searches users matching a query.
final searchUsersProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repo = ref.watch(socialRepositoryProvider);
  return repo.searchUsers(query);
});

/// Controller for social operations (follow / unfollow).
final socialActionsProvider = Provider<SocialActions>((ref) {
  return SocialActions(ref);
});

class SocialActions {
  SocialActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  Future<void> followUser(String targetUserId) async {
    // 1. Update in settings controller for instantaneous reactive UI updates
    await _ref.read(settingsControllerProvider.notifier).followUser(targetUserId);

    // 2. Persist in social repository
    await _repo.followUser(targetUserId);

    // 3. Invalidate relevant queries
    _ref.invalidate(userProfileProvider(targetUserId));
    _ref.invalidate(suggestedUsersProvider);
  }

  Future<void> unfollowUser(String targetUserId) async {
    // 1. Update in settings controller
    await _ref.read(settingsControllerProvider.notifier).unfollowUser(targetUserId);

    // 2. Persist in social repository
    await _repo.unfollowUser(targetUserId);

    // 3. Invalidate relevant queries
    _ref.invalidate(userProfileProvider(targetUserId));
    _ref.invalidate(suggestedUsersProvider);
  }

  Future<void> toggleFollow(String targetUserId) async {
    final isFollowing = _ref.read(isFollowingUserProvider(targetUserId));
    if (isFollowing) {
      await unfollowUser(targetUserId);
    } else {
      await followUser(targetUserId);
    }
  }
}
