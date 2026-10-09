import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/core/di/providers.dart';
import 'package:series_app/core/widgets/app_network_image.dart';
import 'package:series_app/features/main/presentation/screens/main_screen.dart';
import 'package:series_app/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:series_app/features/shows/data/repositories/show_repository_impl.dart';
import 'package:series_app/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:series_app/main.dart';

void main() {
  testWidgets('SeriesApp smoke test - renders tabs and switches navigation',
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
        child: const SeriesApp(home: MainScreen()),
      ),
    );

    // Initial frame
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify main destinations in bottom bar
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    // Default tab is Início (Letterboxd-style Home)
    expect(find.text('POPULAR THIS WEEK'), findsOneWidget);

    // Tap on Explorar tab
    await tester.tap(find.text('Explorar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Catálogo Completo'), findsOneWidget);

    // Tap on Agenda tab
    await tester.tap(find.text('Agenda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(AppBar, 'Agenda'), findsOneWidget);

    // Tap on Perfil tab
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('O Meu Perfil'), findsOneWidget);
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
        child: const SeriesApp(home: MainScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Navigate to Profile tab
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify settings button exists in Profile AppBar
    final settingsBtn = find.byTooltip('Definições');
    expect(settingsBtn, findsOneWidget);

    // Tap on Settings button
    await tester.tap(settingsBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify SettingsScreen loaded
    expect(find.widgetWithText(AppBar, 'Definições'), findsOneWidget);
    expect(find.text('CONTA & PERFIL'), findsOneWidget);
    expect(find.text('PREFERÊNCIAS DE CONTEÚDO & IDIOMA'), findsOneWidget);

    // Tap to open Edit Profile Sheet
    await tester.tap(find.text('Editar Perfil e Avatar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify EditProfileSheet contents
    expect(find.text('Editar Perfil'), findsOneWidget);
    expect(find.text('Nome de Exibição'), findsOneWidget);
    expect(find.text('Nome de Utilizador'), findsOneWidget);
    expect(find.text('Bio Curta'), findsOneWidget);

    // Close sheet
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scroll to verify lower settings sections
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('NOTIFICAÇÕES'), findsOneWidget);
    expect(find.text('ARMAZENAMENTO & DADOS'), findsOneWidget);
    expect(find.text('SOBRE & VERSÃO'), findsOneWidget);
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

  testWidgets('AuthGate displays LoginScreen when unauthenticated and not guest',
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
        child: const SeriesApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify login UI components
    expect(find.text('Iniciar Sessão'), findsOneWidget);
    expect(find.text('Continuar com o Google'), findsOneWidget);
    expect(find.text('Continuar como Convidado'), findsOneWidget);
    expect(find.text('Regista-te'), findsOneWidget);

    // Tap Continuar como Convidado
    final guestBtn = find.text('Continuar como Convidado');
    await tester.ensureVisible(guestBtn);
    await tester.tap(guestBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify transitioned to MainScreen
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
