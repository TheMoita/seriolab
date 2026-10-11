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

  @override
  Future<EpisodeReviewModel?> toggleReaction({
    required int seriesId,
    required int seasonNumber,
    required int episodeNumber,
    required String reviewId,
    required String userId,
    required bool isLike,
  }) async {
    if (userId.trim().isEmpty) return null;

    final reviews = await getReviews(seriesId, seasonNumber, episodeNumber);
    final index = reviews.indexWhere((r) => r.id == reviewId);
    if (index == -1) return null;

    final current = reviews[index];
    final hasLiked = current.likedBy.contains(userId);
    final hasDisliked = current.dislikedBy.contains(userId);

    int newLikes = current.likesCount;
    int newDislikes = current.dislikesCount;
    final newLikedBy = List<String>.from(current.likedBy);
    final newDislikedBy = List<String>.from(current.dislikedBy);

    final Map<String, dynamic> firestoreUpdates = {};

    if (isLike) {
      if (hasLiked) {
        // Toggle off existing like
        newLikedBy.remove(userId);
        newLikes = (newLikes - 1).clamp(0, 999999);
        firestoreUpdates['likesCount'] = FieldValue.increment(-1);
        firestoreUpdates['likedBy'] = FieldValue.arrayRemove([userId]);
      } else {
        // Add like
        newLikedBy.add(userId);
        newLikes += 1;
        firestoreUpdates['likesCount'] = FieldValue.increment(1);
        firestoreUpdates['likedBy'] = FieldValue.arrayUnion([userId]);

        // If previously had dislike, remove it
        if (hasDisliked) {
          newDislikedBy.remove(userId);
          newDislikes = (newDislikes - 1).clamp(0, 999999);
          firestoreUpdates['dislikesCount'] = FieldValue.increment(-1);
          firestoreUpdates['dislikedBy'] = FieldValue.arrayRemove([userId]);
        }
      }
    } else {
      // Dislike
      if (hasDisliked) {
        // Toggle off existing dislike
        newDislikedBy.remove(userId);
        newDislikes = (newDislikes - 1).clamp(0, 999999);
        firestoreUpdates['dislikesCount'] = FieldValue.increment(-1);
        firestoreUpdates['dislikedBy'] = FieldValue.arrayRemove([userId]);
      } else {
        // Add dislike
        newDislikedBy.add(userId);
        newDislikes += 1;
        firestoreUpdates['dislikesCount'] = FieldValue.increment(1);
        firestoreUpdates['dislikedBy'] = FieldValue.arrayUnion([userId]);

        // If previously had like, remove it
        if (hasLiked) {
          newLikedBy.remove(userId);
          newLikes = (newLikes - 1).clamp(0, 999999);
          firestoreUpdates['likesCount'] = FieldValue.increment(-1);
          firestoreUpdates['likedBy'] = FieldValue.arrayRemove([userId]);
        }
      }
    }

    final updatedReview = current.copyWith(
      likesCount: newLikes,
      dislikesCount: newDislikes,
      likedBy: newLikedBy,
      dislikedBy: newDislikedBy,
    );

    reviews[index] = updatedReview;

    // Persist updated list locally
    final key = _metaKey(seriesId, seasonNumber, episodeNumber);
    final encoded = jsonEncode(reviews.map((r) => r.toJson()).toList());
    await _trackingRepo.writeMeta(key, encoded);

    // Persist to Firestore
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('shows')
          .doc('$seriesId')
          .collection('episodes')
          .doc('s${seasonNumber}_e$episodeNumber')
          .collection('reviews')
          .doc(reviewId)
          .update(firestoreUpdates);
    } catch (_) {
      // Offline fallback
    }

    return updatedReview;
  }
}
