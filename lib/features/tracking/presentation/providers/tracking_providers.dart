import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../shows/domain/entities/episode.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/demo_data_seeder.dart';
import '../../data/repositories/user_library_repository_impl.dart';
import '../../data/services/firestore_sync_service.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/entities/tracking_state.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/repositories/user_library_repository.dart';

final userLibraryRepositoryProvider = Provider<UserLibraryRepository>((ref) {
  final syncService = ref.watch(firestoreSyncServiceProvider);
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  return UserLibraryRepositoryImpl(
    syncService: syncService,
    trackingRepo: trackingRepo,
  );
});

final trackingControllerProvider =
    AsyncNotifierProvider<TrackingController, TrackingState>(
  TrackingController.new,
);

/// Derived statistics (episodes, hours, days, per-status counts).
final userStatsProvider = Provider<UserStats?>(
  (ref) => ref.watch(trackingControllerProvider).value?.stats,
);

/// Tracking info for a single show (rebuilds only when that show changes).
final trackedShowProvider = Provider.family<TrackedShow?, int>(
  (ref, showId) => ref.watch(
    trackingControllerProvider.select((s) => s.value?.show(showId)),
  ),
);

/// Owns the user's tracking state and keeps it in sync with SQLite.
///
/// Mutations are serialised so rapid taps never interleave and lose updates.
class TrackingController extends AsyncNotifier<TrackingState> {
  Future<void> _queue = Future.value();

  TrackingRepository get _repo => ref.read(trackingRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();
  TrackingState get _current => state.value ?? TrackingState.empty;
  FirestoreSyncService get _sync => ref.read(firestoreSyncServiceProvider);

  void syncFromRemote(TrackingSnapshot snapshot) {
    state = AsyncData(TrackingState.fromSnapshot(snapshot));
  }

  @override
  Future<TrackingState> build() async {
    final repo = ref.watch(trackingRepositoryProvider);
    final syncService = ref.watch(firestoreSyncServiceProvider);

    // Register active listener with FirestoreSyncService for real-time cloud updates
    final unregister = syncService.addTrackingListener((snapshot) {
      syncFromRemote(snapshot);
    });
    ref.onDispose(unregister);

    if (ref.watch(demoSeedingEnabledProvider)) {
      try {
        await DemoDataSeeder(
          shows: ref.read(showRepositoryProvider),
          tracking: repo,
          clock: ref.read(clockProvider),
        ).seedIfNeeded();
      } catch (e, st) {
        // Demo data is a nicety — never block the app on it.
        debugPrint('Demo seeding failed: $e\n$st');
      }
    }
    return TrackingState.fromSnapshot(await repo.load());
  }

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  TrackedShow _snapshot(
    ShowDetails show,
    TrackingStatus status, {
    TrackedShow? existing,
  }) {
    final now = _now();
    return TrackedShow(
      showId: show.id,
      name: show.name,
      posterUrl: show.posterUrl,
      status: status,
      airedEpisodeCount: show.airedEpisodeCount > 0
          ? show.airedEpisodeCount
          : (show.totalEpisodeCount > 0
              ? show.totalEpisodeCount
              : (existing?.airedEpisodeCount ?? 0)),
      episodeRuntime: show.episodeRuntime > 0
          ? show.episodeRuntime
          : (existing?.episodeRuntime ?? 45),
      showStatus: show.status,
      network: show.primaryNetwork ?? existing?.network,
      addedAt: existing?.addedAt ?? now,
      updatedAt: now,
      overallUserRating: existing?.overallUserRating ?? show.overallUserRating,
      reviewText: existing?.reviewText ?? show.reviewText,
      hasSpoilers: existing?.hasSpoilers ?? show.hasSpoilers,
      loggedAt: existing?.loggedAt ?? show.loggedAt,
      isFavorite: existing?.isFavorite ?? show.isFavorite,
    );
  }

  /// Adds the show to a list, or moves it between lists.
  ///
  /// When marked as [TrackingStatus.completed], all episodes across all seasons
  /// of the show are automatically marked as watched in batch.
  /// Returns `true` if there were previously unwatched episodes.
  Future<bool> setStatus(ShowDetails show, TrackingStatus status) =>
      _serial(() async {
        final current = _current;
        final now = _now();
        var hadUnwatched = false;
        var watchedMap = current.watchedFor(show.id);

        if (status == TrackingStatus.completed) {
          List<Episode> episodes = const [];
          try {
            final showWithEpisodes =
                await ref.read(showRepositoryProvider).getShowWithEpisodes(show.id);
            episodes = showWithEpisodes.episodes;
          } catch (e) {
            debugPrint('Failed to load show episodes for completed status: $e');
          }

          final items = <WatchedEpisode>[];
          final newWatchedMap = {...watchedMap};

          if (episodes.isNotEmpty) {
            final sortedEpisodes = List.of(episodes)
              ..sort((a, b) => a.key.compareTo(b.key));
            for (var i = 0; i < sortedEpisodes.length; i++) {
              final e = sortedEpisodes[i];
              final existing = watchedMap[e.key];
              if (existing == null) {
                hadUnwatched = true;
              }
              final updated = WatchedEpisode(
                showId: show.id,
                key: e.key,
                runtime: existing?.runtime ??
                    ((e.runtime != null && e.runtime! > 0)
                        ? e.runtime!
                        : (show.episodeRuntime > 0 ? show.episodeRuntime : 45)),
                watchedAt: existing?.watchedAt ??
                    now.add(Duration(milliseconds: i)),
                userRating: existing?.userRating,
                reviewText: existing?.reviewText,
                hasSpoilers: existing?.hasSpoilers ?? false,
                loggedAt: existing?.loggedAt,
              );
              items.add(updated);
              newWatchedMap[e.key] = updated;
            }
          } else if (show.regularSeasons.isNotEmpty) {
            final sortedSeasons = List.of(show.regularSeasons)
              ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
            var epCounter = 0;
            for (final s in sortedSeasons) {
              for (var i = 1; i <= s.episodeCount; i++) {
                final key = EpisodeKey(s.seasonNumber, i);
                final existing = watchedMap[key];
                if (existing == null) {
                  hadUnwatched = true;
                }
                final updated = WatchedEpisode(
                  showId: show.id,
                  key: key,
                  runtime: existing?.runtime ??
                      (show.episodeRuntime > 0 ? show.episodeRuntime : 45),
                  watchedAt: existing?.watchedAt ??
                      now.add(Duration(milliseconds: epCounter++)),
                  userRating: existing?.userRating,
                  reviewText: existing?.reviewText,
                  hasSpoilers: existing?.hasSpoilers ?? false,
                  loggedAt: existing?.loggedAt,
                );
                items.add(updated);
                newWatchedMap[key] = updated;
              }
            }
          }

          if (items.isNotEmpty) {
            await _repo.markWatched(items);
            watchedMap = newWatchedMap;
          }
        }

        final existing = current.show(show.id);
        final effectiveAiredCount = (status == TrackingStatus.completed &&
                show.totalEpisodeCount > 0)
            ? show.totalEpisodeCount
            : (existing?.airedEpisodeCount ?? show.airedEpisodeCount);

        final tracked = _snapshot(show, status, existing: existing).copyWith(
          airedEpisodeCount: effectiveAiredCount,
        );
        await _repo.upsertShow(tracked);

        state = AsyncData(
          current.copyWith(
            shows: {...current.shows, show.id: tracked},
            watched: {...current.watched, show.id: watchedMap},
          ),
        );

        _sync.syncTrackedShow(
          tracked,
          watchedEpisodes: watchedMap.values.toList(),
        );

        return hadUnwatched;
      });

  /// Quick status change from a summary card without waiting for full details.
  ///
  /// When marked as [TrackingStatus.completed], all episodes across all seasons
  /// of the show are automatically marked as watched in batch.
  /// Returns `true` if there were previously unwatched episodes.
  Future<bool> setSummaryStatus(ShowSummary show, TrackingStatus status) =>
      _serial(() async {
        final current = _current;
        final existing = current.show(show.id);
        final now = _now();
        var hadUnwatched = false;
        var watchedMap = current.watchedFor(show.id);

        ShowDetails? details;
        if (status == TrackingStatus.completed) {
          try {
            final showWithEpisodes =
                await ref.read(showRepositoryProvider).getShowWithEpisodes(show.id);
            details = showWithEpisodes.show;
            final episodes = showWithEpisodes.episodes;

            final items = <WatchedEpisode>[];
            final newWatchedMap = {...watchedMap};
            final sortedEpisodes = List.of(episodes)
              ..sort((a, b) => a.key.compareTo(b.key));

            for (var i = 0; i < sortedEpisodes.length; i++) {
              final e = sortedEpisodes[i];
              final existingWatched = watchedMap[e.key];
              if (existingWatched == null) {
                hadUnwatched = true;
              }
              final updated = WatchedEpisode(
                showId: show.id,
                key: e.key,
                runtime: existingWatched?.runtime ??
                    ((e.runtime != null && e.runtime! > 0)
                        ? e.runtime!
                        : (details.episodeRuntime > 0
                            ? details.episodeRuntime
                            : (existing?.episodeRuntime ?? 45))),
                watchedAt: existingWatched?.watchedAt ??
                    now.add(Duration(milliseconds: i)),
                userRating: existingWatched?.userRating,
                reviewText: existingWatched?.reviewText,
                hasSpoilers: existingWatched?.hasSpoilers ?? false,
                loggedAt: existingWatched?.loggedAt,
              );
              items.add(updated);
              newWatchedMap[e.key] = updated;
            }

            if (items.isNotEmpty) {
              await _repo.markWatched(items);
              watchedMap = newWatchedMap;
            }
          } catch (e) {
            debugPrint(
                'Failed to load show episodes for summary completed status: $e');
          }
        }

        final tracked = TrackedShow(
          showId: show.id,
          name: show.name,
          posterUrl: show.posterUrl,
          status: status,
          airedEpisodeCount: (status == TrackingStatus.completed &&
                  details != null &&
                  details.totalEpisodeCount > 0)
              ? details.totalEpisodeCount
              : (details?.airedEpisodeCount ??
                  (existing?.airedEpisodeCount ?? 0)),
          episodeRuntime:
              details?.episodeRuntime ?? (existing?.episodeRuntime ?? 45),
          showStatus: details?.status ??
              (existing?.showStatus ?? ShowStatus.returning),
          network: details?.primaryNetwork ?? existing?.network,
          addedAt: existing?.addedAt ?? now,
          updatedAt: now,
          overallUserRating: existing?.overallUserRating,
          reviewText: existing?.reviewText,
          hasSpoilers: existing?.hasSpoilers ?? false,
          loggedAt: existing?.loggedAt,
          isFavorite: existing?.isFavorite ?? false,
        );
        await _repo.upsertShow(tracked);
        state = AsyncData(
          current.copyWith(
            shows: {...current.shows, show.id: tracked},
            watched: {...current.watched, show.id: watchedMap},
          ),
        );

        _sync.syncTrackedShow(
          tracked,
          watchedEpisodes: watchedMap.values.toList(),
        );

        return hadUnwatched;
      });

  /// Stops tracking the show and erases its watched history.
  Future<void> removeShow(int showId) => _serial(() async {
        final current = _current;
        final existing = current.show(showId);
        final prevRating = existing?.overallUserRating;
        await _repo.removeShow(showId);
        state = AsyncData(current.copyWith(
          shows: {...current.shows}..remove(showId),
          watched: {...current.watched}..remove(showId),
        ));
        _sync.deleteTrackedShow(showId);
        if (prevRating != null) {
          final oldHistogramScore = prevRating.clamp(0.5, 10.0);
          await ref
              .read(settingsControllerProvider.notifier)
              .removeRating(oldHistogramScore);
        }
      });

  /// Sets or clears favorite flag in tracking storage.
  Future<void> setIsFavorite(ShowDetails show, bool isFavorite) =>
      _serial(() async {
        final current = _current;
        final existing = current.show(show.id);
        final now = _now();
        if (existing != null) {
          final updated = existing.copyWith(
            isFavorite: isFavorite,
            updatedAt: now,
          );
          await _repo.upsertShow(updated);
          state = AsyncData(current.copyWith(
            shows: {...current.shows, show.id: updated},
          ));
          _sync.syncTrackedShow(
            updated,
            watchedEpisodes: current.watchedFor(show.id).values.toList(),
          );
        } else if (isFavorite) {
          final tracked = _snapshot(show, TrackingStatus.watchlist).copyWith(
            isFavorite: true,
          );
          await _repo.upsertShow(tracked);
          state = AsyncData(current.copyWith(
            shows: {...current.shows, show.id: tracked},
          ));
          _sync.syncTrackedShow(
            tracked,
            watchedEpisodes: current.watchedFor(show.id).values.toList(),
          );
        }
      });

  /// Toggles favorite flag on this show in tracking storage.
  Future<bool> toggleFavorite(ShowDetails show) => _serial(() async {
        final current = _current;
        final existing = current.show(show.id);
        final nextVal = !(existing?.isFavorite ?? show.isFavorite);
        final now = _now();
        final tracked = (existing ?? _snapshot(show, TrackingStatus.watchlist))
            .copyWith(isFavorite: nextVal, updatedAt: now);
        await _repo.upsertShow(tracked);
        state = AsyncData(current.copyWith(
          shows: {...current.shows, show.id: tracked},
        ));
        _sync.syncTrackedShow(
          tracked,
          watchedEpisodes: current.watchedFor(show.id).values.toList(),
        );
        return nextVal;
      });

  Future<void> toggleEpisode(ShowDetails show, Episode episode) =>
      setEpisodesWatched(
        show,
        [episode],
        watched: !_current.isWatched(show.id, episode.key),
      );

  /// Marks/unmarks a batch of episodes (e.g. a whole season).
  ///
  /// Unaired episodes are never marked. Also automates the list status:
  /// * watching an episode moves the show to "A ver";
  /// * catching up on a finished show moves it to "Terminadas";
  /// * un-watching a completed show moves it back to "A ver".
  Future<void> setEpisodesWatched(
    ShowDetails show,
    List<Episode> episodes, {
    required bool watched,
  }) =>
      _serial(() async {
        final now = _now();
        final current = _current;
        final targets = watched
            ? episodes.where((e) => e.isAiredAt(now)).toList()
            : episodes;
        if (targets.isEmpty) return;

        final watchedMap = {...current.watchedFor(show.id)};
        if (watched) {
          final sortedTargets = List.of(targets)
            ..sort((a, b) => a.key.compareTo(b.key));
          final items = <WatchedEpisode>[];
          for (var i = 0; i < sortedTargets.length; i++) {
            final e = sortedTargets[i];
            final existingWatched = watchedMap[e.key];
            items.add(
              WatchedEpisode(
                showId: show.id,
                key: e.key,
                runtime: existingWatched?.runtime ??
                    ((e.runtime != null && e.runtime! > 0)
                        ? e.runtime!
                        : show.episodeRuntime),
                watchedAt: existingWatched?.watchedAt ??
                    now.add(Duration(milliseconds: i)),
                userRating: existingWatched?.userRating,
                reviewText: existingWatched?.reviewText,
                hasSpoilers: existingWatched?.hasSpoilers ?? false,
                loggedAt: existingWatched?.loggedAt,
              ),
            );
          }
          await _repo.markWatched(items);
          for (final item in items) {
            watchedMap[item.key] = item;
          }
        } else {
          final keys = targets.map((e) => e.key).toList();
          await _repo.unmarkWatched(show.id, keys);
          keys.forEach(watchedMap.remove);
        }

        final existing = current.show(show.id);
        final status = _nextStatus(
          current: existing?.status,
          markedWatched: watched,
          watchedRegular: watchedMap.keys.where((k) => !k.isSpecial).length,
          show: show,
        );
        final tracked = _snapshot(show, status, existing: existing);
        await _repo.upsertShow(tracked);

        state = AsyncData(current.copyWith(
          shows: {...current.shows, show.id: tracked},
          watched: {...current.watched, show.id: watchedMap},
        ));

        _sync.syncTrackedShow(
          tracked,
          watchedEpisodes: watchedMap.values.toList(),
        );
      });

  /// Sets or removes an episode rating, review, and log metadata.
  /// Automatically marks episode as watched if it wasn't already watched.
  Future<void> rateEpisode(
    ShowDetails show,
    Episode episode,
    double? rating, {
    String? reviewText,
    bool hasSpoilers = false,
    DateTime? loggedAt,
    bool clearReview = false,
  }) =>
      _serial(() async {
        final now = _now();
        final current = _current;
        final watchedMap = {...current.watchedFor(show.id)};
        final existingWatched = watchedMap[episode.key];
        final prevRating = existingWatched?.userRating;

        if (rating != null || reviewText != null || !clearReview) {
          final updatedWatched = WatchedEpisode(
            showId: show.id,
            key: episode.key,
            runtime: existingWatched?.runtime ??
                (episode.runtime ?? show.episodeRuntime),
            watchedAt: existingWatched?.watchedAt ?? loggedAt ?? now,
            userRating: rating ?? (clearReview ? null : existingWatched?.userRating),
            reviewText: clearReview ? null : (reviewText ?? existingWatched?.reviewText),
            hasSpoilers: clearReview ? false : hasSpoilers,
            loggedAt: loggedAt ?? existingWatched?.loggedAt ?? now,
          );
          await _repo.markWatched([updatedWatched]);
          watchedMap[episode.key] = updatedWatched;

          final existing = current.show(show.id);
          final status = _nextStatus(
            current: existing?.status,
            markedWatched: true,
            watchedRegular:
                watchedMap.keys.where((k) => !k.isSpecial).length,
            show: show,
          );
          final tracked = _snapshot(show, status, existing: existing);
          await _repo.upsertShow(tracked);

          state = AsyncData(current.copyWith(
            shows: {...current.shows, show.id: tracked},
            watched: {...current.watched, show.id: watchedMap},
          ));

          _sync.syncTrackedShow(
            tracked,
            watchedEpisodes: watchedMap.values.toList(),
          );

          if (rating != null) {
            final newHistogramScore = rating.clamp(0.5, 10.0);
            final oldHistogramScore = prevRating?.clamp(0.5, 10.0);
            await ref
                .read(settingsControllerProvider.notifier)
                .recordRating(newHistogramScore, oldScore: oldHistogramScore);
          } else if (prevRating != null && clearReview) {
            final oldHistogramScore = prevRating.clamp(0.5, 10.0);
            await ref
                .read(settingsControllerProvider.notifier)
                .removeRating(oldHistogramScore);
          }
        } else {
          // Remove episode rating & review
          if (existingWatched != null) {
            final updatedWatched = existingWatched.copyWith(
              clearUserRating: true,
              clearReviewText: true,
              hasSpoilers: false,
            );
            await _repo.markWatched([updatedWatched]);
            watchedMap[episode.key] = updatedWatched;

            state = AsyncData(current.copyWith(
              watched: {...current.watched, show.id: watchedMap},
            ));

            final existing = current.show(show.id);
            if (existing != null) {
              _sync.syncTrackedShow(
                existing,
                watchedEpisodes: watchedMap.values.toList(),
              );
            }

            if (prevRating != null) {
              final oldHistogramScore = prevRating.clamp(1.0, 10.0);
              await ref
                  .read(settingsControllerProvider.notifier)
                  .removeRating(oldHistogramScore);
            }
          }
        }
      });

  /// Sets or removes the independent overall rating, review, and log metadata
  /// for the entire series.
  Future<void> setOverallShowRating(
    ShowDetails show,
    double? rating, {
    String? reviewText,
    bool hasSpoilers = false,
    DateTime? loggedAt,
    bool clearReview = false,
  }) =>
      _serial(() async {
        final current = _current;
        final existing = current.show(show.id);
        final prevRating = existing?.overallUserRating;

        if (rating != null || reviewText != null || !clearReview) {
          final tracked = (existing ??
                  _snapshot(show, TrackingStatus.watching))
              .copyWith(
            overallUserRating: rating ?? (clearReview ? null : existing?.overallUserRating),
            clearOverallUserRating: rating == null && clearReview,
            reviewText: clearReview ? null : (reviewText ?? existing?.reviewText),
            clearReviewText: clearReview && reviewText == null,
            hasSpoilers: clearReview ? false : hasSpoilers,
            loggedAt: loggedAt ?? existing?.loggedAt ?? _now(),
          );
          await _repo.upsertShow(tracked);

          state = AsyncData(current.copyWith(
            shows: {...current.shows, show.id: tracked},
          ));

          _sync.syncTrackedShow(
            tracked,
            watchedEpisodes: current.watchedFor(show.id).values.toList(),
          );

          if (rating != null) {
            final newHistogramScore = rating.clamp(0.5, 10.0);
            final oldHistogramScore = prevRating?.clamp(0.5, 10.0);
            await ref
                .read(settingsControllerProvider.notifier)
                .recordRating(newHistogramScore, oldScore: oldHistogramScore);
          } else if (prevRating != null && clearReview) {
            final oldHistogramScore = prevRating.clamp(0.5, 10.0);
            await ref
                .read(settingsControllerProvider.notifier)
                .removeRating(oldHistogramScore);
          }
        } else {
          if (existing != null) {
            final tracked = existing.copyWith(
              clearOverallUserRating: true,
              clearReviewText: true,
              hasSpoilers: false,
            );
            await _repo.upsertShow(tracked);

            state = AsyncData(current.copyWith(
              shows: {...current.shows, show.id: tracked},
            ));

            _sync.syncTrackedShow(
              tracked,
              watchedEpisodes: current.watchedFor(show.id).values.toList(),
            );

            if (prevRating != null) {
              final oldHistogramScore = prevRating.clamp(1.0, 10.0);
              await ref
                  .read(settingsControllerProvider.notifier)
                  .removeRating(oldHistogramScore);
            }
          }
        }
      });

  /// Calculates the next [TrackingStatus] for a show based on watched episodes
  /// and production status.
  ///
  /// Business rules:
  /// - Watching an episode moves an untracked, watchlist, or dropped show to "watching".
  /// - If all available episodes are marked watched:
  ///   * If the show is finished ([ShowStatus.ended] or [ShowStatus.canceled]),
  ///     it transitions to [TrackingStatus.completed].
  ///   * If the show is still ongoing/returning ([ShowStatus.returning],
  ///     [ShowStatus.inProduction], or [ShowStatus.planned]), it remains in
  ///     [TrackingStatus.watching] (up-to-date), as new episodes will air in the future.
  /// - Unmarking an episode on a completed show reverts it to [TrackingStatus.watching].
  static TrackingStatus nextStatusFor({
    required TrackingStatus? current,
    required bool markedWatched,
    required int watchedRegular,
    required int airedEpisodes,
    required bool showFinished,
    int totalEpisodes = 0,
    ShowStatus? seriesStatus,
  }) {
    var status = current ?? TrackingStatus.watching;
    if (markedWatched &&
        (status == TrackingStatus.watchlist ||
            status == TrackingStatus.dropped)) {
      status = TrackingStatus.watching;
    }

    // Determine if the show has concluded its entire run (Ended or Canceled)
    final isFinished = seriesStatus != null
        ? (seriesStatus == ShowStatus.ended ||
            seriesStatus == ShowStatus.canceled ||
            seriesStatus.isFinished)
        : showFinished;

    final effectiveAired = airedEpisodes > 0 ? airedEpisodes : totalEpisodes;
    final caughtUp = effectiveAired > 0 && watchedRegular >= effectiveAired;
    final allEpisodesWatched =
        caughtUp || (totalEpisodes > 0 && watchedRegular >= totalEpisodes);

    // Only transition to completed if the show is finished AND all available/aired episodes are watched.
    final allCompleted = isFinished && allEpisodesWatched;

    if (allCompleted) {
      status = TrackingStatus.completed;
    } else if (!allCompleted && status == TrackingStatus.completed) {
      status = TrackingStatus.watching;
    }
    return status;
  }

  TrackingStatus _nextStatus({
    required TrackingStatus? current,
    required bool markedWatched,
    required int watchedRegular,
    required ShowDetails show,
  }) =>
      nextStatusFor(
        current: current,
        markedWatched: markedWatched,
        watchedRegular: watchedRegular,
        airedEpisodes: show.airedEpisodeCount,
        showFinished: show.status.isFinished,
        totalEpisodes: show.totalEpisodeCount,
        seriesStatus: show.status,
      );
}

/// First aired, unwatched regular episode — the "next to watch".
Episode? nextEpisodeToWatch(
  ShowWithEpisodes data,
  TrackingState state,
  DateTime now,
) {
  for (final e in data.episodes) {
    if (!e.isAiredAt(now)) return null;
    if (!state.isWatched(data.show.id, e.key)) return e;
  }
  return null;
}
