import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/core/widgets/seriolab_logo.dart';
import 'package:seriolab/features/auth/domain/entities/app_user.dart';
import 'package:seriolab/features/auth/presentation/providers/auth_providers.dart';
import 'package:seriolab/features/home/presentation/screens/home_screen.dart';
import 'package:seriolab/features/settings/domain/entities/user_settings.dart';
import 'package:seriolab/features/settings/presentation/providers/settings_providers.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:seriolab/features/tracking/presentation/screens/profile_screen.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._initial);
  final UserSettings _initial;

  @override
  UserSettings build() => _initial;
}

class _FakeAuthNotifier extends AuthController {
  _FakeAuthNotifier(this._user);
  final AppUser? _user;

  @override
  AuthState build() {
    return AuthState(
      user: _user,
    );
  }
}

void main() {
  group('HomeScreen AppBar Badge & ProfileScreen Header Tests', () {
    late InMemoryTrackingRepository inMemoryRepo;
    late ShowRepositoryImpl testRepo;

    setUp(() {
      inMemoryRepo = InMemoryTrackingRepository();
      testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );
    });

    testWidgets('HomeScreen AppBar displays SeriolabLogo without SÉRIES / TV SHOWS badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            demoSeedingEnabledProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Brand logo is rendered
      expect(find.byType(SeriolabLogo), findsOneWidget);

      // Badge is removed
      expect(find.text('SÉRIES'), findsNothing);
      expect(find.text('TV SHOWS'), findsNothing);
      expect(find.text('SERIES'), findsNothing);
    });

    testWidgets('ProfileScreen shows Display Name in AppBar and only @username below avatar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final customSettings = UserSettings.defaultSettings.copyWith(
        displayName: 'Afonso Dias',
        username: 'afonsodias',
        bio: 'Fã incondicional de ficção científica.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(customSettings),
            ),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Static text 'O Meu Perfil' is replaced
      expect(find.text('O Meu Perfil'), findsNothing);

      // 2. Display Name is in the AppBar
      expect(find.widgetWithText(AppBar, 'Afonso Dias'), findsOneWidget);

      // 3. Display Name appears ONLY once across the entire screen (in the AppBar, not duplicated below avatar)
      expect(find.text('Afonso Dias'), findsOneWidget);

      // 4. Username is present below avatar
      expect(find.text('@afonsodias'), findsOneWidget);

      // 5. Bio is present
      expect(find.text('Fã incondicional de ficção científica.'), findsOneWidget);
    });

    testWidgets('ProfileScreen falls back to auth user preferredName when displayName in settings is empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptyNameSettings = UserSettings.defaultSettings.copyWith(
        displayName: '',
        username: 'moita',
      );

      const authUser = AppUser(
        uid: 'user-123',
        email: 'moita@seriolab.com',
        provider: AuthProviderKind.email,
        displayName: 'Tiago Moita',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(emptyNameSettings),
            ),
            authControllerProvider.overrideWith(
              () => _FakeAuthNotifier(authUser),
            ),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // AppBar contains fallback display name
      expect(find.widgetWithText(AppBar, 'Tiago Moita'), findsOneWidget);
      expect(find.text('@moita'), findsOneWidget);
    });
  });
}
