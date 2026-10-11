import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/utils/formatters.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/episode_review_repository_impl.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/domain/entities/episode_review_model.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';

void main() {
  group('Formatters.timeAgo', () {
    final fixedNow = DateTime(2026, 10, 10, 12, 0, 0);

    test('returns "agora mesmo" for timestamps less than 1 minute ago', () {
      final t = fixedNow.subtract(const Duration(seconds: 30));
      expect(Formatters.timeAgo(t, now: fixedNow), 'agora mesmo');
    });

    test('returns minutes ago', () {
      final t = fixedNow.subtract(const Duration(minutes: 15));
      expect(Formatters.timeAgo(t, now: fixedNow), 'há 15m');
    });

    test('returns hours ago', () {
      final t = fixedNow.subtract(const Duration(hours: 4));
      expect(Formatters.timeAgo(t, now: fixedNow), 'há 4h');
    });

    test('returns "ontem" for 1 day ago', () {
      final t = fixedNow.subtract(const Duration(days: 1));
      expect(Formatters.timeAgo(t, now: fixedNow), 'ontem');
    });

    test('returns days ago for multiple days', () {
      final t = fixedNow.subtract(const Duration(days: 4));
      expect(Formatters.timeAgo(t, now: fixedNow), 'há 4 dias');
    });
  });

  group('EpisodeReviewModel', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime(2026, 10, 10, 10, 0, 0);
      final review = EpisodeReviewModel(
        id: 'rev_123',
        episodeKeyString: '100088_s1_e1',
        userId: 'joao_silva',
        username: 'joaosilva',
        userDisplayName: 'João Silva',
        userAvatarId: 'popcorn',
        rating: 9.5,
        comment: 'Excelente episódio!',
        containsSpoilers: true,
        createdAt: now,
        likesCount: 3,
      );

      final json = review.toJson();
      expect(json['id'], 'rev_123');
      expect(json['episodeKeyString'], '100088_s1_e1');
      expect(json['rating'], 9.5);
      expect(json['containsSpoilers'], true);

      final restored = EpisodeReviewModel.fromJson(json);
      expect(restored.id, review.id);
      expect(restored.username, 'joaosilva');
      expect(restored.rating, 9.5);
      expect(restored.containsSpoilers, true);
    });

    test('buildKey formats correctly', () {
      expect(EpisodeReviewModel.buildKey(100088, 1, 4), '100088_s1_e4');
    });
  });

  group('EpisodeReviewRepository & ShowRepository getEpisodeDetails', () {
    late InMemoryTrackingRepository trackingRepo;
    late EpisodeReviewRepositoryImpl reviewRepo;
    late ShowRepositoryImpl showRepo;

    setUp(() {
      trackingRepo = InMemoryTrackingRepository();
      reviewRepo = EpisodeReviewRepositoryImpl(trackingRepo);
      showRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );
    });

    test('getReviews returns empty list when storage empty', () async {
      final reviews = await reviewRepo.getReviews(100088, 1, 1);
      expect(reviews, isEmpty);
    });

    test('addReview persists and prepends new review', () async {
      final newRev = EpisodeReviewModel(
        id: 'user_rev_1',
        episodeKeyString: '100088_s1_e1',
        userId: 'tester',
        username: 'tester',
        userDisplayName: 'Tester Seriolab',
        comment: 'A minha opinião em primeira mão!',
        containsSpoilers: false,
        createdAt: DateTime.now(),
      );

      await reviewRepo.addReview(newRev);

      final updated = await reviewRepo.getReviews(100088, 1, 1);
      expect(updated.first.id, 'user_rev_1');
      expect(updated.first.comment, 'A minha opinião em primeira mão!');
    });

    test('showRepo getEpisodeDetails loads episode details with guest stars and crew', () async {
      final epDetails = await showRepo.getEpisodeDetails(100088, 1, 1);
      expect(epDetails.episode.episodeNumber, 1);
      expect(epDetails.episode.seasonNumber, 1);
      expect(epDetails.directors, isNotEmpty);
      expect(epDetails.writers, isNotEmpty);
      expect(epDetails.guestStars, isNotEmpty);
      expect(epDetails.stillHighResUrl, isNotNull);
    });
  });
}
