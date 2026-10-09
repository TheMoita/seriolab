import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../shows/domain/entities/episode.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/demo_data_seeder.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/entities/tracking_state.dart';
import '../../domain/repositories/tracking_repository.dart';

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

  @override
  Future<TrackingState> build() async {
    final repo = ref.watch(trackingRepositoryProvider);
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
      airedEpisodeCount: show.airedEpisodeCount,
      episodeRuntime: show.episodeRuntime,
      showStatus: show.status,
      network: show.primaryNetwork,
      addedAt: existing?.addedAt ?? now,
      updatedAt: now,
      overallUserRating: existing?.overallUserRating ?? show.overallUserRating,
      reviewText: existing?.reviewText ?? show.reviewText,
      hasSpoilers: existing?.hasSpoilers ?? show.hasSpoilers,
      loggedAt: existing?.loggedAt ?? show.loggedAt,
    );
  }

  /// Adds the show to a list, or moves it between lists.
  Future<void> setStatus(ShowDetails show, TrackingStatus status) =>
      _serial(() async {
        final current = _current;
        final tracked =
            _snapshot(show, status, existing: current.show(show.id));
        await _repo.upsertShow(tracked);
        state = AsyncData(
          current.copyWith(shows: {...current.shows, show.id: tracked}),
        );
      });

  /// Quick status change from a summary card without waiting for full details.
  Future<void> setSummaryStatus(ShowSummary show, TrackingStatus status) =>
      _serial(() async {
        final current = _current;
        final existing = current.show(show.id);
        final now = _now();
        final tracked = TrackedShow(
          showId: show.id,
          name: show.name,
          posterUrl: show.posterUrl,
          status: status,
          airedEpisodeCount: existing?.airedEpisodeCount ?? 0,
          episodeRuntime: existing?.episodeRuntime ?? 45,
          showStatus: existing?.showStatus ?? ShowStatus.returning,
          network: existing?.network,
          addedAt: existing?.addedAt ?? now,
          updatedAt: now,
        );
        await _repo.upsertShow(tracked);
        state = AsyncData(
          current.copyWith(shows: {...current.shows, show.id: tracked}),
        );
      });

  /// Stops tracking the show and erases its watched history.
  Future<void> removeShow(int showId) => _serial(() async {
        final current = _current;
        await _repo.removeShow(showId);
        state = AsyncData(current.copyWith(
          shows: {...current.shows}..remove(showId),
          watched: {...current.watched}..remove(showId),
        ));
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
          final items = [
            for (final e in targets)
              WatchedEpisode(
                showId: show.id,
                key: e.key,
                runtime: e.runtime ?? show.episodeRuntime,
                watchedAt: now,
              ),
          ];
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

          if (rating != null) {
            final newHistogramScore = rating <= 5.0 ? rating * 2.0 : rating;
            final oldHistogramScore = prevRating != null
                ? (prevRating <= 5.0 ? prevRating * 2.0 : prevRating)
                : null;
            await ref
                .read(settingsControllerProvider.notifier)
                .recordRating(newHistogramScore, oldScore: oldHistogramScore);
          } else if (prevRating != null && clearReview) {
            final oldHistogramScore =
                prevRating <= 5.0 ? prevRating * 2.0 : prevRating;
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

            if (prevRating != null) {
              final oldHistogramScore =
                  prevRating <= 5.0 ? prevRating * 2.0 : prevRating;
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

          if (rating != null) {
            final newHistogramScore = rating <= 5.0 ? rating * 2.0 : rating;
            final oldHistogramScore = prevRating != null
                ? (prevRating <= 5.0 ? prevRating * 2.0 : prevRating)
                : null;
            await ref
                .read(settingsControllerProvider.notifier)
                .recordRating(newHistogramScore, oldScore: oldHistogramScore);
          } else if (prevRating != null && clearReview) {
            final oldHistogramScore =
                prevRating <= 5.0 ? prevRating * 2.0 : prevRating;
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

            if (prevRating != null) {
              final oldHistogramScore =
                  prevRating <= 5.0 ? prevRating * 2.0 : prevRating;
              await ref
                  .read(settingsControllerProvider.notifier)
                  .removeRating(oldHistogramScore);
            }
          }
        }
      });

  @visibleForTesting
  static TrackingStatus nextStatusFor({
    required TrackingStatus? current,
    required bool markedWatched,
    required int watchedRegular,
    required int airedEpisodes,
    required bool showFinished,
  }) {
    var status = current ?? TrackingStatus.watching;
    if (markedWatched &&
        (status == TrackingStatus.watchlist ||
            status == TrackingStatus.dropped)) {
      status = TrackingStatus.watching;
    }
    final caughtUp = airedEpisodes > 0 && watchedRegular >= airedEpisodes;
    if (caughtUp && showFinished) {
      status = TrackingStatus.completed;
    } else if (!caughtUp && status == TrackingStatus.completed) {
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
