import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/settings/presentation/providers/settings_providers.dart';
import '../../features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import '../../features/shows/data/datasources/tmdb_api_client.dart';
import '../../features/shows/data/datasources/tmdb_remote_data_source.dart';
import '../../features/shows/data/repositories/show_repository_impl.dart';
import '../../features/shows/domain/repositories/show_repository.dart';
import '../../features/tracking/data/services/firestore_sync_service.dart';
import '../../features/tracking/data/repositories/in_memory_tracking_repository.dart';
import '../../features/tracking/domain/repositories/tracking_repository.dart';
import '../config/app_config.dart';

/// Dependency-injection root. Every dependency is a provider so tests can
/// override it (`ProviderScope(overrides: [...])`).

/// Injectable clock — keeps date-dependent logic testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// TMDB API Client provider configured with active credentials and user selected language.
final tmdbApiClientProvider = Provider<TmdbApiClient>((ref) {
  return TmdbApiClient(
    client: ref.watch(httpClientProvider),
    apiKey: AppConfig.tmdbApiKey,
    defaultLanguage: 'en-US',
  );
});

/// State notifier to allow on-the-fly toggling of demo mock data when API key is missing or for testing.
class MockFallbackNotifier extends Notifier<bool> {
  @override
  bool build() => AppConfig.forceMockData;

  void enableMock() => state = true;
  void disableMock() => state = false;
  void toggle() => state = !state;
}

final mockFallbackProvider =
    NotifierProvider<MockFallbackNotifier, bool>(MockFallbackNotifier.new);

/// Catalogue repository: Real TMDB by default (using TmdbApiClient),
/// or offline mock when explicitly enabled/fallback.
final showRepositoryProvider = Provider<ShowRepository>((ref) {
  final clock = ref.watch(clockProvider);
  final isMockForced = ref.watch(mockFallbackProvider);

  if (isMockForced) {
    return ShowRepositoryImpl(
      remote: MockShowRemoteDataSource(clock: clock),
      isUsingMockData: true,
      clock: clock,
    );
  }

  return ShowRepositoryImpl(
    remote: TmdbRemoteDataSource(
      apiClient: ref.watch(tmdbApiClientProvider),
    ),
    isUsingMockData: false,
    clock: clock,
  );
});

/// Local tracking storage. Overridden in `main()` with the SQLite
/// implementation; defaults to in-memory (tests / fallback).
final trackingRepositoryProvider =
    Provider<TrackingRepository>((ref) => InMemoryTrackingRepository());

/// Firestore cloud sync service ensuring persistent cross-session & cross-install state.
final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return FirestoreSyncService(
    trackingRepo: trackingRepo,
    settingsRepo: settingsRepo,
  );
});

/// Whether to pre-populate a demo profile on first launch.
final demoSeedingEnabledProvider = Provider<bool>(
  (ref) => false,
);
