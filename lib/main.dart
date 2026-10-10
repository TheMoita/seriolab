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
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/main/presentation/screens/splash_screen.dart';
import 'features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'features/tracking/data/repositories/sqflite_tracking_repository.dart';
import 'features/tracking/domain/repositories/tracking_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT', null);

  try {
    await Firebase.initializeApp();
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

class SeriolabApp extends StatelessWidget {
  const SeriolabApp({
    super.key,
    this.showSplash = false,
    this.home,
  });

  final bool showSplash;
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    Widget resolveHome() {
      if (home != null) return home!;
      if (showSplash) return const SplashScreen();
      return const AuthGate();
    }

    return MaterialApp(
      title: 'Seriolab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'PT'),
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      home: resolveHome(),
    );
  }
}

/// Backwards compatibility alias for tests.
typedef SeriesApp = SeriolabApp;

