import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../shows/domain/entities/episode.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/repositories/tracking_repository.dart';

/// SQLite-backed tracking storage — works fully offline.
class SqfliteTrackingRepository implements TrackingRepository {
  SqfliteTrackingRepository(this._db);

  final Database _db;

  @override
  Future<TrackingSnapshot> load() async {
    final showRows = await _db.query(AppDatabase.trackedShows);
    final episodeRows = await _db.query(AppDatabase.watchedEpisodes);
    return TrackingSnapshot(
      shows: showRows.map(_showFromRow).toList(),
      episodes: episodeRows.map(_episodeFromRow).toList(),
    );
  }

  @override
  Future<void> upsertShow(TrackedShow show) => _db.insert(
        AppDatabase.trackedShows,
        _showToRow(show),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> removeShow(int showId) => _db.transaction((txn) async {
        await txn.delete(AppDatabase.trackedShows,
            where: 'show_id = ?', whereArgs: [showId]);
        await txn.delete(AppDatabase.watchedEpisodes,
            where: 'show_id = ?', whereArgs: [showId]);
      });

  @override
  Future<void> markWatched(List<WatchedEpisode> episodes) async {
    if (episodes.isEmpty) return;
    final batch = _db.batch();
    for (final e in episodes) {
      batch.insert(
        AppDatabase.watchedEpisodes,
        {
          'show_id': e.showId,
          'season_number': e.key.season,
          'episode_number': e.key.episode,
          'runtime': e.runtime,
          'watched_at': e.watchedAt.millisecondsSinceEpoch,
          'user_rating': e.userRating,
          'review_text': e.reviewText,
          'has_spoilers': e.hasSpoilers ? 1 : 0,
          'logged_at': e.loggedAt?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> unmarkWatched(int showId, List<EpisodeKey> keys) async {
    if (keys.isEmpty) return;
    final batch = _db.batch();
    for (final k in keys) {
      batch.delete(
        AppDatabase.watchedEpisodes,
        where: 'show_id = ? AND season_number = ? AND episode_number = ?',
        whereArgs: [showId, k.season, k.episode],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> unmarkAllWatched(int showId) async {
    await _db.delete(
      AppDatabase.watchedEpisodes,
      where: 'show_id = ?',
      whereArgs: [showId],
    );
  }

  @override
  Future<String?> readMeta(String key) async {
    final rows = await _db.query(AppDatabase.meta,
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> writeMeta(String key, String value) => _db.insert(
        AppDatabase.meta,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // ---------------------------------------------------------------------------

  static Map<String, Object?> _showToRow(TrackedShow s) => {
        'show_id': s.showId,
        'name': s.name,
        'poster_url': s.posterUrl,
        'status': s.status.name,
        'aired_episode_count': s.airedEpisodeCount,
        'episode_runtime': s.episodeRuntime,
        'show_status': s.showStatus.name,
        'network': s.network,
        'added_at': s.addedAt.millisecondsSinceEpoch,
        'updated_at': s.updatedAt.millisecondsSinceEpoch,
        'overall_user_rating': s.overallUserRating,
        'review_text': s.reviewText,
        'has_spoilers': s.hasSpoilers ? 1 : 0,
        'logged_at': s.loggedAt?.millisecondsSinceEpoch,
        'is_favorite': s.isFavorite ? 1 : 0,
      };

  static TrackedShow _showFromRow(Map<String, Object?> r) => TrackedShow(
        showId: r['show_id']! as int,
        name: r['name']! as String,
        posterUrl: r['poster_url'] as String?,
        status: TrackingStatus.fromName(r['status']! as String),
        airedEpisodeCount: r['aired_episode_count']! as int,
        episodeRuntime: r['episode_runtime']! as int,
        showStatus: ShowStatus.fromName(r['show_status'] as String?),
        network: r['network'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch(r['added_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at']! as int),
        overallUserRating: (r['overall_user_rating'] as num?)?.toDouble(),
        reviewText: r['review_text'] as String?,
        hasSpoilers: (r['has_spoilers'] as int?) == 1,
        loggedAt: r['logged_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(r['logged_at']! as int)
            : null,
        isFavorite: (r['is_favorite'] as int?) == 1,
      );

  static WatchedEpisode _episodeFromRow(Map<String, Object?> r) =>
      WatchedEpisode(
        showId: r['show_id']! as int,
        key: EpisodeKey(
            r['season_number']! as int, r['episode_number']! as int),
        runtime: r['runtime']! as int,
        watchedAt:
            DateTime.fromMillisecondsSinceEpoch(r['watched_at']! as int),
        userRating: (r['user_rating'] as num?)?.toDouble(),
        reviewText: r['review_text'] as String?,
        hasSpoilers: (r['has_spoilers'] as int?) == 1,
        loggedAt: r['logged_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(r['logged_at']! as int)
            : null,
      );
}
