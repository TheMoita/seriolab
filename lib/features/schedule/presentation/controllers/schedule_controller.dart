import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../shows/domain/entities/episode.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../data/repositories/schedule_repository_impl.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/repositories/schedule_repository.dart';

/// Provider for ScheduleRepository
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepositoryImpl(
    showRepository: ref.watch(showRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

@immutable
class ScheduleState {
  const ScheduleState({
    this.watching = const [],
    this.comingSoon = const [],
  });

  final List<CurrentlyWatchingItem> watching;
  final List<ComingSoonItem> comingSoon;

  ScheduleState copyWith({
    List<CurrentlyWatchingItem>? watching,
    List<ComingSoonItem>? comingSoon,
  }) =>
      ScheduleState(
        watching: watching ?? this.watching,
        comingSoon: comingSoon ?? this.comingSoon,
      );
}

/// Controller that computes and manages the two schedule sections:
/// 1. "A Ver Atualmente" (Currently Watching)
/// 2. "Brevemente" (Coming Soon)
class ScheduleController extends AsyncNotifier<ScheduleState> {
  ScheduleRepository get _repo => ref.read(scheduleRepositoryProvider);

  @override
  Future<ScheduleState> build() async {
    final trackingState = ref.watch(trackingControllerProvider).value;
    if (trackingState == null) return const ScheduleState();

    final repo = ref.watch(scheduleRepositoryProvider);
    final rawWatching = await repo.getCurrentlyWatching(trackingState);
    final watching = rawWatching
        .where((item) =>
            !item.isCaughtUp && item.nextEpisode != null && item.isAired)
        .toList();
    final comingSoon = await repo.getComingSoon(trackingState);

    return ScheduleState(
      watching: watching,
      comingSoon: comingSoon,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final trackingState = ref.read(trackingControllerProvider).value;
      if (trackingState == null) return const ScheduleState();

      final rawWatching = await _repo.getCurrentlyWatching(trackingState);
      final watching = rawWatching
          .where((item) =>
              !item.isCaughtUp && item.nextEpisode != null && item.isAired)
          .toList();
      final comingSoon = await _repo.getComingSoon(trackingState);

      return ScheduleState(
        watching: watching,
        comingSoon: comingSoon,
      );
    });
  }

  /// Marks an episode as watched in batch and automatically advances tracking state.
  Future<void> markEpisodeWatched({
    required ShowDetails show,
    required Episode episode,
  }) async {
    await ref.read(trackingControllerProvider.notifier).setEpisodesWatched(
      show,
      [episode],
      watched: true,
    );
  }
}

final scheduleControllerProvider =
    AsyncNotifierProvider<ScheduleController, ScheduleState>(
  ScheduleController.new,
);
