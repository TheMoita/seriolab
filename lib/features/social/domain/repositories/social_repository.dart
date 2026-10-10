import '../entities/user_profile.dart';

/// Repository contract for the social following/followers system.
abstract class SocialRepository {
  /// Follows the user with [targetUserId].
  Future<void> followUser(String targetUserId);

  /// Unfollows the user with [targetUserId].
  Future<void> unfollowUser(String targetUserId);

  /// Checks whether the current user is following [targetUserId].
  Future<bool> isFollowing(String targetUserId);

  /// Retrieves the list of followers for [userId].
  Future<List<UserProfile>> getFollowers(String userId);

  /// Retrieves the list of users followed by [userId].
  Future<List<UserProfile>> getFollowing(String userId);

  /// Searches users by username or display name with query [query].
  Future<List<UserProfile>> searchUsers(String query);

  /// Retrieves full profile details for [userId].
  Future<UserProfile?> getUserProfile(String userId);

  /// Retrieves suggested users from the community for discovery.
  Future<List<UserProfile>> getSuggestedUsers();
}
