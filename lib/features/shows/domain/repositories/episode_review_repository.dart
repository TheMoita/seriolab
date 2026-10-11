import '../entities/episode_review_model.dart';

abstract interface class EpisodeReviewRepository {
  Future<List<EpisodeReviewModel>> getReviews(
    int seriesId,
    int seasonNumber,
    int episodeNumber,
  );

  Future<void> addReview(EpisodeReviewModel review);

  /// Toggles Like or Dislike reaction on a comment.
  ///
  /// - If [isLike] is true:
  ///   - If user already liked: removes like (neutral).
  ///   - If user disliked: removes dislike and adds like.
  ///   - Else: adds like.
  /// - If [isLike] is false:
  ///   - If user already disliked: removes dislike (neutral).
  ///   - If user liked: removes like and adds dislike.
  ///   - Else: adds dislike.
  Future<EpisodeReviewModel?> toggleReaction({
    required int seriesId,
    required int seasonNumber,
    required int episodeNumber,
    required String reviewId,
    required String userId,
    required bool isLike,
  });
}

/// Convenience alias matching user naming conventions
typedef CommentRepository = EpisodeReviewRepository;
