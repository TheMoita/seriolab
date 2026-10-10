import '../entities/episode_review_model.dart';

abstract interface class EpisodeReviewRepository {
  Future<List<EpisodeReviewModel>> getReviews(
    int seriesId,
    int seasonNumber,
    int episodeNumber,
  );

  Future<void> addReview(EpisodeReviewModel review);
}
