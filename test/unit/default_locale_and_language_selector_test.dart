import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/core/l10n/app_localizations.dart';
import 'package:seriolab/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:seriolab/features/settings/domain/entities/user_settings.dart';
import 'package:seriolab/features/settings/presentation/providers/settings_providers.dart';
import 'package:seriolab/features/settings/presentation/screens/settings_screen.dart';
import 'package:seriolab/features/settings/presentation/widgets/language_selector_bottom_sheet.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';

void main() {
  group('Default English Locale & Language Switcher Unit Tests', () {
    test('AppLocalizations.fromLanguageCode defaults to English for null or unknown codes', () {
      expect(AppLocalizations.fromLanguageCode(null), isA<AppLocalizationsEn>());
      expect(AppLocalizations.fromLanguageCode(''), isA<AppLocalizationsEn>());
      expect(AppLocalizations.fromLanguageCode('fr'), isA<AppLocalizationsEn>());
      expect(AppLocalizations.fromLanguageCode('de-DE'), isA<AppLocalizationsEn>());
      expect(AppLocalizations.fromLanguageCode('en'), isA<AppLocalizationsEn>());
      expect(AppLocalizations.fromLanguageCode('en-US'), isA<AppLocalizationsEn>());
      expect(AppLocalizations.fromLanguageCode('pt-PT'), isA<AppLocalizationsPt>());
      expect(AppLocalizations.fromLanguageCode('pt-BR'), isA<AppLocalizationsPt>());
      expect(AppLocalizations.fromLanguageCode('es-ES'), isA<AppLocalizationsEs>());
    });

    test('UserSettings defaultSettings has English (en-US) as initial language', () {
      const defaults = UserSettings.defaultSettings;
      expect(defaults.language, 'en-US');
      expect(defaults.tmdbLanguageCode, 'en-US');
    });

    test('SettingsRepository loads English on first launch and persists language updates', () async {
      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);

      // First run: Nothing in storage
      final initial = await settingsRepo.getSettings();
      expect(initial.language, 'en-US');

      // Change language and verify persistence
      final updated = initial.copyWith(language: 'pt-PT');
      await settingsRepo.saveSettings(updated);

      final reloaded = await settingsRepo.getSettings();
      expect(reloaded.language, 'pt-PT');

      // Check that the dedicated language key is also written
      final metaLanguage = await trackingRepo.readMeta('selected_language_code');
      expect(metaLanguage, 'pt-PT');
    });

    test('LanguageSelectorBottomSheet contains all 4 supported languages with flags and labels', () {
      final options = LanguageSelectorBottomSheet.supportedLanguages;
      expect(options.length, 4);

      final codes = options.map((o) => o.code).toList();
      expect(codes, containsAll(['en-US', 'pt-PT', 'pt-BR', 'es-ES']));

      expect(LanguageSelectorBottomSheet.getDisplayName('en-US'), 'English (US) 🇺🇸');
      expect(LanguageSelectorBottomSheet.getDisplayName('en'), 'English (US) 🇺🇸');
      expect(LanguageSelectorBottomSheet.getDisplayName('pt-PT'), 'Português (Portugal) 🇵🇹');
      expect(LanguageSelectorBottomSheet.getDisplayName('pt'), 'Português (Portugal) 🇵🇹');
      expect(LanguageSelectorBottomSheet.getDisplayName('pt-BR'), 'Português (Brasil) 🇧🇷');
      expect(LanguageSelectorBottomSheet.getDisplayName('es-ES'), 'Español (España) 🇪🇸');
    });
  });

  group('LanguageSelectorBottomSheet Widget Tests', () {
    testWidgets('renders all supported options and checkmark on active English language',
        (WidgetTester tester) async {
      final trackingRepo = InMemoryTrackingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(trackingRepo),
            settingsRepositoryProvider
                .overrideWithValue(SettingsRepositoryImpl(trackingRepo)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LanguageSelectorBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & close button
      expect(find.text('App Language'), findsOneWidget);

      // All 4 options visible
      expect(find.text('English (US) 🇺🇸'), findsOneWidget);
      expect(find.text('Português (Portugal) 🇵🇹'), findsOneWidget);
      expect(find.text('Português (Brasil) 🇧🇷'), findsOneWidget);
      expect(find.text('Español (España) 🇪🇸'), findsOneWidget);

      // Default is English, so checkmark is present
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('selecting Portuguese updates state and saves to repository',
        (WidgetTester tester) async {
      final trackingRepo = InMemoryTrackingRepository();
      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(trackingRepo),
          settingsRepositoryProvider
              .overrideWithValue(SettingsRepositoryImpl(trackingRepo)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LanguageSelectorBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Portuguese (Portugal)
      await tester.tap(find.text('Português (Portugal) 🇵🇹'));
      await tester.pumpAndSettle();

      // Provider updated
      expect(
        container.read(settingsControllerProvider).language,
        'pt-PT',
      );

      // Persisted to storage
      final savedCode = await trackingRepo.readMeta('selected_language_code');
      expect(savedCode, 'pt-PT');
    });

    testWidgets('SettingsScreen displays active language label and opens modal on tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackingRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(trackingRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            demoSeedingEnabledProvider.overrideWithValue(false),
            settingsRepositoryProvider
                .overrideWithValue(SettingsRepositoryImpl(trackingRepo)),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
            ],
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Subtitle shows English (US) 🇺🇸
      expect(find.text('English (US) 🇺🇸'), findsOneWidget);

      // Tap the Language tile
      await tester.tap(find.text('App Language'));
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.byType(LanguageSelectorBottomSheet), findsOneWidget);
      expect(find.text('Português (Brasil) 🇧🇷'), findsOneWidget);
    });
  });
}
