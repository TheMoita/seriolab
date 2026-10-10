import 'dart:convert';

import '../../../tracking/domain/repositories/tracking_repository.dart';
import '../../domain/entities/episode_review_model.dart';
import '../../domain/repositories/episode_review_repository.dart';

class EpisodeReviewRepositoryImpl implements EpisodeReviewRepository {
  EpisodeReviewRepositoryImpl(this._trackingRepo);

  final TrackingRepository _trackingRepo;

  static String _metaKey(int seriesId, int seasonNumber, int episodeNumber) =>
      'ep_reviews_${seriesId}_s${seasonNumber}_e$episodeNumber';

  @override
  Future<List<EpisodeReviewModel>> getReviews(
    int seriesId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final key = _metaKey(seriesId, seasonNumber, episodeNumber);
    try {
      final raw = await _trackingRepo.readMeta(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(EpisodeReviewModel.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  @override
  Future<void> addReview(EpisodeReviewModel review) async {
    final parts = review.episodeKeyString.split('_');
    // Expected: {seriesId}_s{seasonNumber}_e{episodeNumber}
    if (parts.length != 3) return;
    final seriesId = int.tryParse(parts[0]) ?? 0;
    final seasonNumber = int.tryParse(parts[1].replaceFirst('s', '')) ?? 0;
    final episodeNumber = int.tryParse(parts[2].replaceFirst('e', '')) ?? 0;

    final existing = await getReviews(seriesId, seasonNumber, episodeNumber);
    final updated = [review, ...existing];

    final key = _metaKey(seriesId, seasonNumber, episodeNumber);
    final encoded = jsonEncode(updated.map((r) => r.toJson()).toList());
    await _trackingRepo.writeMeta(key, encoded);
  }
}
