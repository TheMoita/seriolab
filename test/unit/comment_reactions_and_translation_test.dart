import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seriolab/core/services/translation_service.dart';
import 'package:seriolab/features/shows/domain/entities/episode_review_model.dart';
import 'package:seriolab/features/shows/presentation/providers/episode_review_providers.dart';
import 'package:seriolab/features/shows/presentation/widgets/comment_card_widget.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:seriolab/features/shows/data/repositories/episode_review_repository_impl.dart';

void main() {
  group('EpisodeReviewModel (EpisodeCommentModel) Tests', () {
    test('default reactions are 0 and empty lists', () {
      final review = EpisodeReviewModel(
        id: 'rev-1',
        episodeKeyString: '10_s1_e1',
        userId: 'u1',
        userDisplayName: 'User 1',
        username: 'user1',
        comment: 'Great episode!',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(review.likesCount, 0);
      expect(review.dislikesCount, 0);
      expect(review.likedBy, isEmpty);
      expect(review.dislikedBy, isEmpty);
      expect(review.isLikedBy('u1'), isFalse);
      expect(review.isDislikedBy('u1'), isFalse);
    });

    test('fromJson and toJson preserve likes, dislikes, likedBy, and dislikedBy', () {
      final json = {
        'id': 'rev-2',
        'episodeKeyString': '100_s2_e3',
        'userId': 'author-123',
        'userDisplayName': 'Alice',
        'username': 'alice',
        'comment': 'Awesome twist!',
        'rating': 4.5,
        'containsSpoilers': false,
        'likesCount': 5,
        'dislikesCount': 2,
        'likedBy': ['u1', 'u2', 'u3'],
        'dislikedBy': ['u4', 'u5'],
        'createdAt': DateTime(2026, 3, 10).toIso8601String(),
      };

      final model = EpisodeReviewModel.fromJson(json);

      expect(model.id, 'rev-2');
      expect(model.likesCount, 5);
      expect(model.dislikesCount, 2);
      expect(model.likedBy, ['u1', 'u2', 'u3']);
      expect(model.dislikedBy, ['u4', 'u5']);
      expect(model.isLikedBy('u1'), isTrue);
      expect(model.isLikedBy('u99'), isFalse);
      expect(model.isDislikedBy('u4'), isTrue);
      expect(model.isDislikedBy('u1'), isFalse);

      final encoded = model.toJson();
      expect(encoded['likesCount'], 5);
      expect(encoded['dislikesCount'], 2);
      expect(encoded['likedBy'], ['u1', 'u2', 'u3']);
      expect(encoded['dislikedBy'], ['u4', 'u5']);
    });

    test('copyWith updates reaction fields correctly', () {
      final review = EpisodeReviewModel(
        id: 'rev-3',
        episodeKeyString: '10_s1_e1',
        userId: 'u1',
        userDisplayName: 'User 1',
        username: 'user1',
        comment: 'Nice',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = review.copyWith(
        likesCount: 10,
        dislikesCount: 3,
        likedBy: ['user-a'],
        dislikedBy: ['user-b'],
      );

      expect(updated.likesCount, 10);
      expect(updated.dislikesCount, 3);
      expect(updated.likedBy, ['user-a']);
      expect(updated.dislikedBy, ['user-b']);
    });
  });

  group('EpisodeReviewRepositoryImpl toggleReaction Tests', () {
    test('toggling like and dislike with mutual exclusion', () async {
      final inMemoryTracking = InMemoryTrackingRepository();
      final repo = EpisodeReviewRepositoryImpl(inMemoryTracking);

      final initialReview = EpisodeReviewModel(
        id: 'review-100',
        episodeKeyString: EpisodeReviewModel.buildKey(42, 1, 1),
        userId: 'author-1',
        userDisplayName: 'Author',
        username: 'author',
        comment: 'Amazing season finale!',
        createdAt: DateTime.now(),
      );

      // Pre-populate tracking storage with the review
      await inMemoryTracking.writeMeta(
        'ep_reviews_42_s1_e1',
        jsonEncode([initialReview.toJson()]),
      );

      // 1. User 'voter1' likes the comment
      final afterLike = await repo.toggleReaction(
        seriesId: 42,
        seasonNumber: 1,
        episodeNumber: 1,
        reviewId: 'review-100',
        userId: 'voter1',
        isLike: true,
      );

      expect(afterLike, isNotNull);
      expect(afterLike!.likesCount, 1);
      expect(afterLike.dislikesCount, 0);
      expect(afterLike.likedBy, contains('voter1'));
      expect(afterLike.dislikedBy, isEmpty);

      // 2. User 'voter1' dislikes the comment -> Like must be cancelled and Dislike activated
      final afterDislikeSwitch = await repo.toggleReaction(
        seriesId: 42,
        seasonNumber: 1,
        episodeNumber: 1,
        reviewId: 'review-100',
        userId: 'voter1',
        isLike: false,
      );

      expect(afterDislikeSwitch, isNotNull);
      expect(afterDislikeSwitch!.likesCount, 0);
      expect(afterDislikeSwitch.dislikesCount, 1);
      expect(afterDislikeSwitch.likedBy, isNot(contains('voter1')));
      expect(afterDislikeSwitch.dislikedBy, contains('voter1'));

      // 3. User 'voter1' clicks Dislike again -> Dislike is toggled off
      final afterDislikeToggleOff = await repo.toggleReaction(
        seriesId: 42,
        seasonNumber: 1,
        episodeNumber: 1,
        reviewId: 'review-100',
        userId: 'voter1',
        isLike: false,
      );

      expect(afterDislikeToggleOff, isNotNull);
      expect(afterDislikeToggleOff!.likesCount, 0);
      expect(afterDislikeToggleOff.dislikesCount, 0);
      expect(afterDislikeToggleOff.likedBy, isEmpty);
      expect(afterDislikeToggleOff.dislikedBy, isEmpty);
    });
  });

  group('TranslationService Tests', () {
    test('translates comment via MyMemory API and caches the result', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(request.url.host, 'api.mymemory.translated.net');
        return http.Response(
          jsonEncode({
            'responseData': {
              'translatedText': 'Este é um excelente episódio!',
              'match': 0.95,
            },
            'responseStatus': 200,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = TranslationService(client: mockClient);

      // First call -> triggers network request
      final result1 = await service.translateComment(
        'This is a great episode!',
        'pt',
      );
      expect(result1, 'Este é um excelente episódio!');
      expect(requestCount, 1);
      expect(service.cacheSize, 1);

      // Second call with same text and target language -> serves from cache without network call
      final result2 = await service.translateComment(
        'This is a great episode!',
        'pt',
      );
      expect(result2, 'Este é um excelente episódio!');
      expect(requestCount, 1); // No new request made!
    });

    test('falls back to Google Translate when primary API fails', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'api.mymemory.translated.net') {
          return http.Response('Error', 500);
        }
        if (request.url.host == 'translate.googleapis.com') {
          return http.Response(
            jsonEncode([
              [['Excelente episódio.', 'Great episode.', null, null]],
              null,
              'en',
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = TranslationService(client: mockClient);
      final result = await service.translateComment('Great episode.', 'pt');

      expect(result, 'Excelente episódio.');
    });

    test('returns empty string on empty input', () async {
      final service = TranslationService(client: MockClient((_) async => http.Response('err', 500)));
      expect(await service.translateComment('', 'pt'), '');
      expect(await service.translateComment('   ', 'pt'), '');
    });
  });

  group('CommentCardWidget Tests', () {
    testWidgets('renders author, text, like and dislike buttons, and handles toggles',
        (WidgetTester tester) async {
      final testReview = EpisodeReviewModel(
        id: 'rev-ui-1',
        episodeKeyString: EpisodeReviewModel.buildKey(10, 1, 1),
        userId: 'other-user',
        userDisplayName: 'Maria Santos',
        username: 'mariasantos',
        comment: 'This is an awesome plot twist!',
        rating: 4.0,
        likesCount: 2,
        dislikesCount: 0,
        likedBy: ['uA', 'uB'],
        dislikedBy: [],
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final inMemoryTracking = InMemoryTrackingRepository();
      await inMemoryTracking.writeMeta(
        'ep_reviews_10_s1_e1',
        jsonEncode([testReview.toJson()]),
      );

      final reviewRepo = EpisodeReviewRepositoryImpl(inMemoryTracking);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'responseData': {
              'translatedText': 'Esta é uma reviravolta impressionante no enredo!',
            },
            'responseStatus': 200,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            episodeReviewRepositoryProvider.overrideWithValue(reviewRepo),
            translationServiceProvider.overrideWithValue(TranslationService(client: mockClient)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CommentCardWidget(
                review: testReview,
                seriesId: 10,
                seasonNumber: 1,
                episodeNumber: 1,
                currentUserId: 'current-user-123',
                isOwnComment: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check author and comment text
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('This is an awesome plot twist!'), findsOneWidget);
      expect(find.text('★ 4.0'), findsOneWidget);

      // Check likes counter (2)
      expect(find.text('2'), findsOneWidget);

      // Check Translate button
      expect(find.text('Traduzir'), findsOneWidget);

      // Tap Like button -> optimistic update to 3
      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_rounded), findsOneWidget);

      // Tap Dislike button -> like switches to dislike (likes decrements to 2, dislikes becomes 1)
      await tester.tap(find.byIcon(Icons.thumb_down_outlined));
      await tester.pump();

      expect(find.text('2'), findsOneWidget); // likes
      expect(find.text('1'), findsOneWidget); // dislikes
      expect(find.byIcon(Icons.thumb_down_rounded), findsOneWidget);

      // Tap Translate button
      await tester.tap(find.text('Traduzir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Translated text is displayed
      expect(find.text('Esta é uma reviravolta impressionante no enredo!'), findsOneWidget);
      expect(find.text('Traduzido automaticamente'), findsOneWidget);
      expect(find.text('Ver original'), findsOneWidget);

      // Tap "Ver original" to revert back to original
      await tester.tap(find.text('Ver original'));
      await tester.pump();

      expect(find.text('This is an awesome plot twist!'), findsOneWidget);
      expect(find.text('Traduzir'), findsOneWidget);
    });
  });
}
