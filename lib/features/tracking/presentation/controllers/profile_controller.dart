import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/entities/tracking_state.dart';
import '../providers/tracking_providers.dart';

/// Real-time ProfileController managing reactive library data and profile statistics.
class ProfileController extends AsyncNotifier<TrackingState> {
  StreamSubscription<List<TrackedShow>>? _librarySub;

  @override
  Future<TrackingState> build() async {
    final tracking = ref.watch(trackingControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (user != null) {
      final libraryRepo = ref.watch(userLibraryRepositoryProvider);
      _librarySub?.cancel();
      _librarySub = libraryRepo.watchLibrary(user.uid).listen((shows) {
        final current = state.value ?? TrackingState.empty;
        final updatedShows = {for (final s in shows) s.showId: s};
        state = AsyncData(current.copyWith(shows: updatedShows));
      });
      ref.onDispose(() => _librarySub?.cancel());
    }

    return tracking.value ?? TrackingState.empty;
  }
}

/// Provider for [ProfileController] providing live reactive library and tracking state.
final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, TrackingState>(
  ProfileController.new,
);

/// Provider for real-time statistics in the user's profile.
final profileStatsProvider = Provider<UserStats?>(
  (ref) =>
      ref.watch(profileControllerProvider).value?.stats ??
      ref.watch(userStatsProvider),
);
