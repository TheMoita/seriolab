import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/repositories/episode_review_repository_impl.dart';
import '../../domain/entities/episode_review_model.dart';
import '../../domain/repositories/episode_review_repository.dart';
import 'show_providers.dart';

final episodeReviewRepositoryProvider =
    Provider<EpisodeReviewRepository>((ref) {
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  return EpisodeReviewRepositoryImpl(trackingRepo);
});

final episodeReviewsProvider =
    FutureProvider.autoDispose.family<List<EpisodeReviewModel>, EpisodeRef>(
  (ref, r) => ref.watch(episodeReviewRepositoryProvider).getReviews(
        r.showId,
        r.seasonNumber,
        r.episodeNumber,
      ),
);
