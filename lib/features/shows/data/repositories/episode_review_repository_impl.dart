import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    List<EpisodeReviewModel> localReviews = const [];
    try {
      final raw = await _trackingRepo.readMeta(key);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        localReviews = decoded
            .whereType<Map<String, dynamic>>()
            .map(EpisodeReviewModel.fromJson)
            .toList();
      }
    } catch (_) {}

    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('shows')
          .doc('$seriesId')
          .collection('episodes')
          .doc('s${seasonNumber}_e$episodeNumber')
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final remoteReviews = querySnapshot.docs
            .map((doc) => EpisodeReviewModel.fromJson(doc.data()))
            .toList();

        final seen = <String>{};
        final combined = <EpisodeReviewModel>[];
        for (final r in [...localReviews, ...remoteReviews]) {
          if (seen.add(r.id)) {
            combined.add(r);
          }
        }
        return combined;
      }
    } catch (_) {}

    return localReviews;
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

    // Persist to Firestore subcollections
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Show episode reviews subcollection: shows/{seriesId}/episodes/s{season}_e{episode}/reviews/{id}
      await firestore
          .collection('shows')
          .doc('$seriesId')
          .collection('episodes')
          .doc('s${seasonNumber}_e$episodeNumber')
          .collection('reviews')
          .doc(review.id)
          .set(review.toJson(), SetOptions(merge: true));

      // 2. User watched episode reviews subcollection: users/{uid}/watched_episodes/{id}/reviews/{id}
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('watched_episodes')
            .doc('${seriesId}_${seasonNumber}_$episodeNumber')
            .collection('reviews')
            .doc(review.id)
            .set(review.toJson(), SetOptions(merge: true));
      }
    } catch (_) {
      // Offline fallback
    }
  }
}
