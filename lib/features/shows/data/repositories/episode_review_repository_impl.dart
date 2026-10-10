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

    // Return default seed community reviews for lively community discussion
    final now = DateTime.now();
    final epKey = EpisodeReviewModel.buildKey(seriesId, seasonNumber, episodeNumber);
    return [
      EpisodeReviewModel(
        id: 'seed_1_$epKey',
        episodeKeyString: epKey,
        userId: 'marta_s',
        username: 'martas',
        userDisplayName: 'Marta Santos',
        userAvatarId: 'popcorn',
        rating: 9.0,
        comment:
            'Que episódio fantástico! A cinematografia e a realização estiveram a um nível cinematográfico.',
        containsSpoilers: false,
        createdAt: now.subtract(const Duration(days: 2, hours: 4)),
        likesCount: 14,
      ),
      EpisodeReviewModel(
        id: 'seed_2_$epKey',
        episodeKeyString: epKey,
        userId: 'diogo_f',
        username: 'diogof',
        userDisplayName: 'Diogo Ferreira',
        userAvatarId: 'film_roll',
        rating: 8.5,
        comment:
            'O desfecho deste episódio deixou-me boquiaberto! Não estava nada à espera que aquela decisão fosse mudar o rumo da história desta maneira.',
        containsSpoilers: true,
        createdAt: now.subtract(const Duration(days: 1, hours: 8)),
        likesCount: 9,
      ),
      EpisodeReviewModel(
        id: 'seed_3_$epKey',
        episodeKeyString: epKey,
        userId: 'bea_l',
        username: 'bealima',
        userDisplayName: 'Beatriz Lima',
        userAvatarId: 'clapper',
        rating: 8.0,
        comment:
            'Muito bom desenvolvimento emocional dos protagonistas. O ritmo funcionou lindamente.',
        containsSpoilers: false,
        createdAt: now.subtract(const Duration(hours: 15)),
        likesCount: 5,
      ),
    ];
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
