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
    List<CurrentlyWatchingItem>? upNext,
    this.startWatching = const [],
    this.resume = const [],
    this.comingSoon = const [],
    List<CurrentlyWatchingItem>? watching,
  }) : upNext = upNext ?? watching ?? const [];

  final List<CurrentlyWatchingItem> upNext;
  final List<CurrentlyWatchingItem> startWatching;
  final List<CurrentlyWatchingItem> resume;
  final List<ComingSoonItem> comingSoon;

  /// Backwards compatibility getter for tests and existing callers.
  List<CurrentlyWatchingItem> get watching => upNext;

  int get watchlistTotalCount =>
      upNext.length + startWatching.length + resume.length;

  bool get isWatchlistEmpty =>
      upNext.isEmpty && startWatching.isEmpty && resume.isEmpty;

  ScheduleState copyWith({
    List<CurrentlyWatchingItem>? upNext,
    List<CurrentlyWatchingItem>? startWatching,
    List<CurrentlyWatchingItem>? resume,
    List<ComingSoonItem>? comingSoon,
    List<CurrentlyWatchingItem>? watching,
  }) =>
      ScheduleState(
        upNext: upNext ?? watching ?? this.upNext,
        startWatching: startWatching ?? this.startWatching,
        resume: resume ?? this.resume,
        comingSoon: comingSoon ?? this.comingSoon,
      );
}

/// Controller that computes and manages the schedule sections:
/// 1. "Lista para Assistir" / Watchlist (Up Next, Start Watching, Resume)
/// 2. "Brevemente" (Coming Soon)
class ScheduleController extends AsyncNotifier<ScheduleState> {
  ScheduleRepository get _repo => ref.read(scheduleRepositoryProvider);

  @override
  Future<ScheduleState> build() async {
    final trackingState = ref.watch(trackingControllerProvider).value;
    if (trackingState == null) return const ScheduleState();

    final repo = ref.watch(scheduleRepositoryProvider);
    final results = await Future.wait([
      repo.getUpNext(trackingState),
      repo.getStartWatching(trackingState),
      repo.getResume(trackingState),
      repo.getComingSoon(trackingState),
    ]);

    final rawUpNext = results[0] as List<CurrentlyWatchingItem>;
    final upNext = rawUpNext
        .where((item) =>
            !item.isCaughtUp && item.nextEpisode != null && item.isAired)
        .toList();
    final startWatching = results[1] as List<CurrentlyWatchingItem>;
    final resume = results[2] as List<CurrentlyWatchingItem>;
    final comingSoon = results[3] as List<ComingSoonItem>;

    return ScheduleState(
      upNext: upNext,
      startWatching: startWatching,
      resume: resume,
      comingSoon: comingSoon,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final trackingState = ref.read(trackingControllerProvider).value;
      if (trackingState == null) return const ScheduleState();

      final results = await Future.wait([
        _repo.getUpNext(trackingState),
        _repo.getStartWatching(trackingState),
        _repo.getResume(trackingState),
        _repo.getComingSoon(trackingState),
      ]);

      final rawUpNext = results[0] as List<CurrentlyWatchingItem>;
      final upNext = rawUpNext
          .where((item) =>
              !item.isCaughtUp && item.nextEpisode != null && item.isAired)
          .toList();
      final startWatching = results[1] as List<CurrentlyWatchingItem>;
      final resume = results[2] as List<CurrentlyWatchingItem>;
      final comingSoon = results[3] as List<ComingSoonItem>;

      return ScheduleState(
        upNext: upNext,
        startWatching: startWatching,
        resume: resume,
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
