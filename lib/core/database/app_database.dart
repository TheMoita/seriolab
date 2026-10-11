import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite database holding all offline user data (tracked shows & episodes).
abstract final class AppDatabase {
  static const String fileName = 'seriolab.db';
  static const String legacyFileName = 'series_app.db';
  static const int version = 4;

  static const String trackedShows = 'tracked_shows';
  static const String watchedEpisodes = 'watched_episodes';
  static const String meta = 'app_meta';

  /// Opens (and migrates) the database. [factory]/[path] are injectable so
  /// tests can use `sqflite_common_ffi` with an in-memory database.
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    String dbPath;
    if (path != null) {
      dbPath = path;
    } else {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final docsPath = p.join(docsDir.path, fileName);
        final legacyDocsPath = p.join(docsDir.path, legacyFileName);

        // Migrate legacy database from series_app.db in documents if it exists
        try {
          final legacyDocsFile = File(legacyDocsPath);
          final docsFile = File(docsPath);
          if (await legacyDocsFile.exists() && !await docsFile.exists()) {
            await docsFile.parent.create(recursive: true);
            await legacyDocsFile.copy(docsPath);

            final legacyWal = File('$legacyDocsPath-wal');
            if (await legacyWal.exists()) {
              await legacyWal.copy('$docsPath-wal');
            }
            final legacyShm = File('$legacyDocsPath-shm');
            if (await legacyShm.exists()) {
              await legacyShm.copy('$docsPath-shm');
            }
            final legacyJournal = File('$legacyDocsPath-journal');
            if (await legacyJournal.exists()) {
              await legacyJournal.copy('$docsPath-journal');
            }
          }
        } catch (_) {}

        // Migrate legacy database from getDatabasesPath() if it exists and docsPath doesn't yet
        try {
          final legacyDir = await dbFactory.getDatabasesPath();
          for (final candidateName in [legacyFileName, fileName]) {
            final legacyPath = p.join(legacyDir, candidateName);
            final legacyFile = File(legacyPath);
            final docsFile = File(docsPath);
            if (await legacyFile.exists() && !await docsFile.exists()) {
              await docsFile.parent.create(recursive: true);
              await legacyFile.copy(docsPath);

              final legacyWal = File('$legacyPath-wal');
              if (await legacyWal.exists()) {
                await legacyWal.copy('$docsPath-wal');
              }
              final legacyShm = File('$legacyPath-shm');
              if (await legacyShm.exists()) {
                await legacyShm.copy('$docsPath-shm');
              }
              final legacyJournal = File('$legacyPath-journal');
              if (await legacyJournal.exists()) {
                await legacyJournal.copy('$docsPath-journal');
              }
              break;
            }
          }
        } catch (_) {}

        dbPath = docsPath;
      } catch (_) {
        // Fallback to sqflite databases path (e.g. in environments where path_provider is unavailable)
        dbPath = p.join(await dbFactory.getDatabasesPath(), fileName);
      }
    }

    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: (db, oldVersion, newVersion) async {
          // Safe non-destructive downgrade handler to avoid dropping tables or throwing
          // if an APK with a previous/different schema version is run.
        },
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE $trackedShows (
          show_id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          poster_url TEXT,
          status TEXT NOT NULL,
          aired_episode_count INTEGER NOT NULL DEFAULT 0,
          episode_runtime INTEGER NOT NULL DEFAULT 0,
          show_status TEXT NOT NULL,
          network TEXT,
          added_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          overall_user_rating REAL,
          review_text TEXT,
          has_spoilers INTEGER NOT NULL DEFAULT 0,
          logged_at INTEGER,
          is_favorite INTEGER NOT NULL DEFAULT 0
        )''')
      ..execute('''
        CREATE TABLE $watchedEpisodes (
          show_id INTEGER NOT NULL,
          season_number INTEGER NOT NULL,
          episode_number INTEGER NOT NULL,
          runtime INTEGER NOT NULL DEFAULT 0,
          watched_at INTEGER NOT NULL,
          user_rating REAL,
          review_text TEXT,
          has_spoilers INTEGER NOT NULL DEFAULT 0,
          logged_at INTEGER,
          PRIMARY KEY (show_id, season_number, episode_number)
        )''')
      ..execute(
          'CREATE INDEX idx_watched_show ON $watchedEpisodes (show_id)')
      ..execute('''
        CREATE TABLE $meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )''');
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE $trackedShows ADD COLUMN overall_user_rating REAL',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $watchedEpisodes ADD COLUMN user_rating REAL',
        );
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE $trackedShows ADD COLUMN review_text TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $trackedShows ADD COLUMN has_spoilers INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $trackedShows ADD COLUMN logged_at INTEGER',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE $watchedEpisodes ADD COLUMN review_text TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $watchedEpisodes ADD COLUMN has_spoilers INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $watchedEpisodes ADD COLUMN logged_at INTEGER',
        );
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE $trackedShows ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
  }
}
