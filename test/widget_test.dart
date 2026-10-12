import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/core/widgets/app_network_image.dart';
import 'package:seriolab/features/main/presentation/screens/main_screen.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:seriolab/features/auth/data/services/local_auth_service.dart';
import 'package:seriolab/features/shows/presentation/screens/show_detail_screen.dart';
import 'package:seriolab/main.dart';

void main() {
  testWidgets('SeriolabApp smoke test - renders tabs and switches navigation',
      (WidgetTester tester) async {
    final inMemoryRepo = InMemoryTrackingRepository();
    final testRepo = ShowRepositoryImpl(
      remote: MockShowRemoteDataSource(latency: Duration.zero),
      isUsingMockData: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
        child: const SeriolabApp(home: MainScreen()),
      ),
    );

    // Initial frame
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify main destinations in bottom bar
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Default tab is Início (Letterboxd-style Home, localized in English by default)
    expect(find.text('POPULAR THIS WEEK'), findsOneWidget);

    // Tap on Explore tab
    await tester.tap(find.text('Explore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Full Catalogue'), findsOneWidget);

    // Tap on Schedule tab
    await tester.tap(find.text('Schedule'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(AppBar, 'Schedule'), findsOneWidget);

    // Tap on Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(AppBar, 'Afonso Dias'), findsOneWidget);
  });

  testWidgets('SettingsScreen navigation and EditProfileSheet smoke test',
      (WidgetTester tester) async {
    final inMemoryRepo = InMemoryTrackingRepository();
    final testRepo = ShowRepositoryImpl(
      remote: MockShowRemoteDataSource(latency: Duration.zero),
      isUsingMockData: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
        child: const SeriolabApp(home: MainScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Navigate to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify settings button exists in Profile AppBar
    final settingsBtn = find.byTooltip('Settings');
    expect(settingsBtn, findsOneWidget);

    // Tap on Settings button
    await tester.tap(settingsBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify SettingsScreen loaded
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('ACCOUNT & PROFILE'), findsOneWidget);
    expect(find.text('CONTENT & LANGUAGE PREFERENCES'), findsOneWidget);

    // Tap to open Edit Profile Sheet
    await tester.tap(find.text('Edit Profile & Avatar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify EditProfileSheet contents
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Display Name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Short Bio'), findsOneWidget);

    // Close sheet
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scroll to verify lower settings sections
    await tester.drag(find.byType(ListView).last, const Offset(0, -1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('STORAGE & DATA'), findsOneWidget);
    expect(find.text('ABOUT & VERSION'), findsOneWidget);
  });

  testWidgets('AppNetworkImage renders Seriolab placeholder with title on null image',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppNetworkImage(
            imageUrl: null,
            fallbackImageUrl: null,
            title: 'Carrie',
            width: 120,
            height: 180,
          ),
        ),
      ),
    );

    expect(find.text('Carrie'), findsOneWidget);
    expect(find.byIcon(Icons.movie_filter_rounded), findsOneWidget);
  });

  testWidgets('AuthGate strictly requires authentication and removes guest mode',
      (WidgetTester tester) async {
    final inMemoryRepo = InMemoryTrackingRepository();
    final localAuth = LocalAuthService(inMemoryRepo);
    await localAuth.registerWithEmailAndPassword(
      'tester@seriolab.app',
      'password123',
      'tester',
    );
    await localAuth.signOut();

    final testRepo = ShowRepositoryImpl(
      remote: MockShowRemoteDataSource(latency: Duration.zero),
      isUsingMockData: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
        child: const SeriolabApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify login UI components
    expect(find.text('Sign In'), findsNWidgets(2));
    expect(find.text('Sign up'), findsOneWidget);
    // Google Sign-In and guest mode are completely removed
    expect(find.text('Continuar com o Google'), findsNothing);
    expect(find.text('Ou continua com'), findsNothing);
    expect(find.text('Continuar como Convidado'), findsNothing);

    // Enter email & password and tap Sign In to authenticate
    await tester.enterText(find.byType(TextFormField).at(0), 'tester@seriolab.app');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    final signInBtn = find.widgetWithText(FilledButton, 'Sign In');
    await tester.ensureVisible(signInBtn);
    await tester.tap(signInBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify transitioned to MainScreen
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets(
      'Profile displays empty bio action and RatingsBreakdown empty state',
      (WidgetTester tester) async {
    final inMemoryRepo = InMemoryTrackingRepository();
    final testRepo = ShowRepositoryImpl(
      remote: MockShowRemoteDataSource(latency: Duration.zero),
      isUsingMockData: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
        child: const SeriolabApp(home: MainScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Navigate to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Bio is empty by default -> "Add bio" is shown
    expect(find.text('Add bio'), findsOneWidget);

    // Tap "Add bio" -> opens EditProfileSheet
    await tester.tap(find.text('Add bio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Edit Profile'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scroll down to RatingsBreakdownSection
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify RatingsBreakdownSection displays 0-ratings state
    expect(find.text('RATINGS'), findsOneWidget);
    expect(find.text('Average: —'), findsOneWidget);
    expect(find.text('(0)'), findsOneWidget);
    expect(find.text('You haven\'t rated any shows yet'), findsOneWidget);
  });

  testWidgets(
      'ShowDetailScreen rating cards render single star icon and clean typography',
      (WidgetTester tester) async {
    final inMemoryRepo = InMemoryTrackingRepository();
    final testRepo = ShowRepositoryImpl(
      remote: MockShowRemoteDataSource(latency: Duration.zero),
      isUsingMockData: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
        ],
        child: const MaterialApp(
          home: ShowDetailScreen(showId: 1396),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Community Card
    expect(find.text('COMMUNITY'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
    expect(find.text('8.9'), findsNWidgets(2)); // Backdrop pill and Community rating card

    // Verify User Rating Card (unrated state)
    expect(find.text('YOUR RATING'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.text('Rate Show'), findsOneWidget);

    // Verify that neither rating card contains a duplicate '★' text character
    expect(find.text('8.9 ★'), findsNothing);
    expect(find.text('★ Rate Show'), findsNothing);
  });
}
