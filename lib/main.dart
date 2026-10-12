import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/app_database.dart';
import 'core/di/providers.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/main/presentation/screens/splash_screen.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'features/tracking/data/repositories/sqflite_tracking_repository.dart';
import 'features/tracking/domain/repositories/tracking_repository.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('en_US', null),
    initializeDateFormatting('pt_PT', null),
    initializeDateFormatting('pt_BR', null),
    initializeDateFormatting('es_ES', null),
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint('Nota: Firebase não inicializado ($e). A usar modo local/reserva.');
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Nota: Ficheiro .env não carregado ($e).');
  }

  TrackingRepository trackingRepo;
  if (kIsWeb) {
    trackingRepo = InMemoryTrackingRepository();
  } else {
    try {
      final db = await AppDatabase.open();
      trackingRepo = SqfliteTrackingRepository(db);
    } catch (e) {
      debugPrint('Falha ao abrir SQLite, a usar armazenamento em memória: $e');
      trackingRepo = InMemoryTrackingRepository();
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        trackingRepositoryProvider.overrideWithValue(trackingRepo),
      ],
      child: const SeriolabApp(showSplash: true),
    ),
  );
}

class SeriolabApp extends ConsumerWidget {
  const SeriolabApp({
    super.key,
    this.showSplash = false,
    this.home,
  });

  final bool showSplash;
  final Widget? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final locale = _resolveLocale(settings.language);

    Widget resolveHome() {
      if (home != null) return home!;
      if (showSplash) return const SplashScreen();
      return const AuthGate();
    }

    return MaterialApp(
      title: 'Seriolab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: locale,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        // Respect explicit user setting if available
        if (settings.language.isNotEmpty) {
          return locale;
        }
        // Match device locale if supported
        if (deviceLocale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == deviceLocale.languageCode) {
              if (supported.countryCode == null ||
                  supported.countryCode == deviceLocale.countryCode) {
                return supported;
              }
            }
          }
        }
        // Fallback to English (en-US)
        return const Locale('en', 'US');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('en', 'US'),
        Locale('pt', 'PT'),
        Locale('pt', 'BR'),
        Locale('es', 'ES'),
      ],
      home: resolveHome(),
    );
  }

  static Locale _resolveLocale(String? language) {
    if (language == null || language.isEmpty) {
      return const Locale('en', 'US');
    }
    final normalized = language.replaceAll('_', '-');
    if (normalized.contains('-')) {
      final parts = normalized.split('-');
      return Locale(parts[0], parts[1]);
    }
    return switch (normalized.toLowerCase()) {
      'en' => const Locale('en', 'US'),
      'pt' => const Locale('pt', 'PT'),
      'es' => const Locale('es', 'ES'),
      _ => const Locale('en', 'US'),
    };
  }
}

/// Backwards compatibility alias for tests.
typedef SeriesApp = SeriolabApp;

