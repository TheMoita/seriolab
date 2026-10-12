import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/features/auth/domain/entities/app_user.dart';
import 'package:seriolab/features/auth/presentation/providers/auth_providers.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';
import 'package:seriolab/features/tracking/presentation/screens/profile_screen.dart';
import 'package:seriolab/features/tracking/presentation/widgets/recent_activity_section.dart';
import 'package:seriolab/features/tracking/presentation/widgets/top_favorites_section.dart';

void main() {
  group('ProfileScreen Privacy & Header Cleaning', () {
    late InMemoryTrackingRepository inMemoryRepo;
    late ShowRepositoryImpl testRepo;

    setUp(() {
      inMemoryRepo = InMemoryTrackingRepository();
      testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );
    });

    testWidgets(
        'ProfileScreen hides user email completely from header while keeping username and bio action',
        (tester) async {
      const authenticatedUser = AppUser(
        uid: 'user_123',
        email: 'afonso.privado@exemplo.pt',
        displayName: 'Afonso Moita',
        provider: AuthProviderKind.email,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            demoSeedingEnabledProvider.overrideWithValue(false),
            authControllerProvider.overrideWith(
              () => _MockAuthController(
                const AuthState(user: authenticatedUser),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Display name and username should be visible
      expect(find.text('Afonso Dias'), findsOneWidget);
      expect(find.text('@afonsodias'), findsOneWidget);

      // Email must strictly NOT be displayed anywhere in the profile
      expect(find.text('afonso.privado@exemplo.pt'), findsNothing);
      expect(find.byIcon(Icons.mail_outline_rounded), findsNothing);

      // Bio button/action should remain visible
      expect(find.text('Add bio'), findsOneWidget);
    });

    testWidgets(
        'TopFavoritesSection renders title without "X/5 selecionadas" badge',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TopFavoritesSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section title is present
      expect(find.text('TOP 5'), findsOneWidget);

      // Counter text like "0/5 selecionadas" must NOT exist
      expect(find.textContaining('selecionadas'), findsNothing);
    });

    testWidgets(
        'RecentActivitySection renders title without "X recentes" counter badge',
        (tester) async {
      final sampleEpisodes = [
        WatchedEpisode(
          showId: 1399,
          key: const EpisodeKey(1, 1),
          runtime: 50,
          watchedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecentActivitySection(customEpisodes: sampleEpisodes),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section title is present
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);

      // Counter text like "1 recentes" must NOT exist
      expect(find.textContaining('recentes'), findsNothing);
    });
  });
}

class _MockAuthController extends AuthController {
  _MockAuthController(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}
