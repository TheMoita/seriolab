import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../settings/domain/entities/user_settings.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../shows/domain/entities/episode.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../presentation/providers/tracking_providers.dart';

/// Service responsible for two-way synchronization between local SQLite/in-memory
/// storage and Cloud Firestore under `users/{uid}`.
///
/// Firestore is the primary cloud source of truth, ensuring 100% data persistence
/// across APK updates, reinstalls, or device transitions.
class FirestoreSyncService {
  FirestoreSyncService({
    FirebaseFirestore? firestore,
    required this.trackingRepo,
    required this.settingsRepo,
  }) : _firestoreInstance = firestore;

  final FirebaseFirestore? _firestoreInstance;
  final TrackingRepository trackingRepo;
  final SettingsRepository settingsRepo;

  TrackingRepository get _trackingRepo => trackingRepo;
  SettingsRepository get _settingsRepo => settingsRepo;

  String? _activeUid;
  bool _isSyncingDown = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _watchlistSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _favoritesSubscription;

  /// Returns whether Firebase is initialized and Firestore is available.
  bool get isAvailable {
    if (_firestoreInstance != null) return true;
    return Firebase.apps.isNotEmpty;
  }

  FirebaseFirestore? get _firestore {
    if (_firestoreInstance != null) return _firestoreInstance;
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? get activeUid => _activeUid;

  /// Stops all active Firestore listeners.
  void stopSync() {
    _cancelSubscriptions();
    _activeUid = null;
  }

  void _cancelSubscriptions() {
    _watchlistSubscription?.cancel();
    _watchlistSubscription = null;
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _favoritesSubscription?.cancel();
    _favoritesSubscription = null;
  }

  /// Triggers full reactive sync for the authenticated user [uid].
  Future<void> syncUser(
    String uid, {
    TrackingController? trackingController,
    SettingsNotifier? settingsNotifier,
  }) async {
    final firestore = _firestore;
    if (firestore == null || uid.trim().isEmpty) return;

    _activeUid = uid;

    try {
      final userDocRef = firestore.collection('users').doc(uid);

      // 1. Maintain root user record
      try {
        await userDocRef.set({
          'uid': uid,
          'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('FirestoreSyncService: root doc set note: $e');
      }

      // 2. Profile Sync (users/{uid}/profile/info)
      final profileDocRef = userDocRef.collection('profile').doc('info');
      try {
        final profileSnapshot = await profileDocRef.get();
        if (profileSnapshot.exists && profileSnapshot.data() != null) {
          final remoteSettings = profileFromMap(profileSnapshot.data()!);
          await _settingsRepo.saveSettings(remoteSettings);
          settingsNotifier?.syncFromRemote(remoteSettings);
        } else {
          // Upload local settings to Firestore
          final localSettings = await _settingsRepo.getSettings();
          await profileDocRef.set(userSettingsToMap(localSettings));
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Profile sync note: $e');
      }

      // 3. Favorites Sync (users/{uid}/favorites/top_five)
      final favDocRef = userDocRef.collection('favorites').doc('top_five');
      try {
        final favSnapshot = await favDocRef.get();
        if (favSnapshot.exists && favSnapshot.data() != null) {
          final (topFive, allFavs) = favoritesFromMap(favSnapshot.data()!);
          settingsNotifier?.syncFavoritesFromRemote(topFive, allFavs);
        } else {
          // Upload local favorites to Firestore
          final localSettings = await _settingsRepo.getSettings();
          await favDocRef.set(favoritesToMap(localSettings));
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Favorites sync note: $e');
      }

      // 4. Watchlist Sync (users/{uid}/watchlist/{seriesId})
      final watchlistCol = userDocRef.collection('watchlist');
      try {
        final watchlistSnapshot = await watchlistCol.get();
        final localSnapshot = await _trackingRepo.load();
        final localWatchedMap = <int, List<WatchedEpisode>>{};
        for (final ep in localSnapshot.episodes) {
          localWatchedMap.putIfAbsent(ep.showId, () => []).add(ep);
        }

        if (watchlistSnapshot.docs.isNotEmpty) {
          final remoteShowIds = <int>{};
          for (final doc in watchlistSnapshot.docs) {
            final data = doc.data();
            final show = trackedShowFromMap(data);
            final episodes = watchedEpisodesFromMap(show.showId, data);
            remoteShowIds.add(show.showId);

            await _trackingRepo.upsertShow(show);
            if (episodes.isNotEmpty) {
              await _trackingRepo.markWatched(episodes);
            }
          }

          // If local database had shows not present in Firestore, push them up
          for (final localShow in localSnapshot.shows) {
            if (!remoteShowIds.contains(localShow.showId)) {
              await watchlistCol.doc('${localShow.showId}').set(
                    trackedShowToMap(
                      localShow,
                      watchedEpisodes: localWatchedMap[localShow.showId] ?? const [],
                    ),
                  );
            }
          }

          final mergedSnapshot = await _trackingRepo.load();
          trackingController?.syncFromRemote(mergedSnapshot);
        } else if (localSnapshot.shows.isNotEmpty) {
          // Upload local shows to Firestore
          for (final localShow in localSnapshot.shows) {
            await watchlistCol.doc('${localShow.showId}').set(
                  trackedShowToMap(
                    localShow,
                    watchedEpisodes: localWatchedMap[localShow.showId] ?? const [],
                  ),
                );
          }
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Watchlist sync note: $e');
      }

      // 5. Setup live reactive snapshot listeners
      _startSubscriptions(uid, trackingController, settingsNotifier);
    } catch (e, st) {
      debugPrint('FirestoreSyncService: Error during syncUser: $e\n$st');
    }
  }

  void _startSubscriptions(
    String uid,
    TrackingController? trackingController,
    SettingsNotifier? settingsNotifier,
  ) {
    _cancelSubscriptions();
    final firestore = _firestore;
    if (firestore == null) return;

    final userDocRef = firestore.collection('users').doc(uid);

    // Watchlist listener
    _watchlistSubscription = userDocRef.collection('watchlist').snapshots().listen(
      (querySnap) async {
        if (_isSyncingDown) return;
        _isSyncingDown = true;
        try {
          for (final docChange in querySnap.docChanges) {
            if (docChange.type == DocumentChangeType.removed) {
              final showId = int.tryParse(docChange.doc.id);
              if (showId != null) {
                await _trackingRepo.removeShow(showId);
              }
            } else {
              final data = docChange.doc.data();
              if (data != null) {
                final show = trackedShowFromMap(data);
                final episodes = watchedEpisodesFromMap(show.showId, data);
                await _trackingRepo.upsertShow(show);
                if (episodes.isNotEmpty) {
                  await _trackingRepo.markWatched(episodes);
                }
              }
            }
          }
          final updated = await _trackingRepo.load();
          trackingController?.syncFromRemote(updated);
        } catch (e) {
          debugPrint('FirestoreSyncService: Watchlist live listener error: $e');
        } finally {
          _isSyncingDown = false;
        }
      },
      onError: (e) {
        debugPrint('FirestoreSyncService: Watchlist subscription error: $e');
      },
    );

    // Profile listener
    _profileSubscription =
        userDocRef.collection('profile').doc('info').snapshots().listen(
      (docSnap) async {
        if (_isSyncingDown || !docSnap.exists || docSnap.data() == null) return;
        _isSyncingDown = true;
        try {
          final remoteSettings = profileFromMap(docSnap.data()!);
          await _settingsRepo.saveSettings(remoteSettings);
          settingsNotifier?.syncFromRemote(remoteSettings);
        } catch (e) {
          debugPrint('FirestoreSyncService: Profile live listener error: $e');
        } finally {
          _isSyncingDown = false;
        }
      },
      onError: (e) {
        debugPrint('FirestoreSyncService: Profile subscription error: $e');
      },
    );

    // Favorites listener
    _favoritesSubscription =
        userDocRef.collection('favorites').doc('top_five').snapshots().listen(
      (docSnap) async {
        if (_isSyncingDown || !docSnap.exists || docSnap.data() == null) return;
        _isSyncingDown = true;
        try {
          final (topFive, allFavs) = favoritesFromMap(docSnap.data()!);
          settingsNotifier?.syncFavoritesFromRemote(topFive, allFavs);
        } catch (e) {
          debugPrint('FirestoreSyncService: Favorites live listener error: $e');
        } finally {
          _isSyncingDown = false;
        }
      },
      onError: (e) {
        debugPrint('FirestoreSyncService: Favorites subscription error: $e');
      },
    );
  }

  /// Syncs an individual show and its watched episodes to `users/{uid}/watchlist/{seriesId}`.
  Future<void> syncTrackedShow(
    TrackedShow show, {
    List<WatchedEpisode>? watchedEpisodes,
    String? uid,
  }) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _activeUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final docRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('watchlist')
          .doc('${show.showId}');
      await docRef.set(
        trackedShowToMap(show, watchedEpisodes: watchedEpisodes),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FirestoreSyncService: Error syncing show ${show.showId}: $e');
    }
  }

  /// Removes an individual show from `users/{uid}/watchlist/{seriesId}`.
  Future<void> deleteTrackedShow(int showId, {String? uid}) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _activeUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final docRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('watchlist')
          .doc('$showId');
      await docRef.delete();
    } catch (e) {
      debugPrint('FirestoreSyncService: Error deleting show $showId: $e');
    }
  }

  /// Syncs user profile details to `users/{uid}/profile/info`.
  Future<void> syncUserProfile(UserSettings settings, {String? uid}) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _activeUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final docRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('profile')
          .doc('info');
      await docRef.set(userSettingsToMap(settings), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService: Error syncing profile: $e');
    }
  }

  /// Syncs top 5 and favorites to `users/{uid}/favorites/top_five`.
  Future<void> syncFavorites(UserSettings settings, {String? uid}) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _activeUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final docRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('favorites')
          .doc('top_five');
      await docRef.set(favoritesToMap(settings), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService: Error syncing favorites: $e');
    }
  }

  // --- Static Mappings ---

  static Map<String, dynamic> trackedShowToMap(
    TrackedShow show, {
    List<WatchedEpisode>? watchedEpisodes,
  }) {
    final map = <String, dynamic>{
      'showId': show.showId,
      'name': show.name,
      'posterUrl': show.posterUrl,
      'status': show.status.name,
      'airedEpisodeCount': show.airedEpisodeCount,
      'episodeRuntime': show.episodeRuntime,
      'showStatus': show.showStatus.name,
      'network': show.network,
      'addedAt': show.addedAt.millisecondsSinceEpoch,
      'updatedAt': show.updatedAt.millisecondsSinceEpoch,
      'overallUserRating': show.overallUserRating,
      'reviewText': show.reviewText,
      'hasSpoilers': show.hasSpoilers,
      'loggedAt': show.loggedAt?.millisecondsSinceEpoch,
      'isFavorite': show.isFavorite,
    };

    if (watchedEpisodes != null) {
      map['watchedEpisodes'] = watchedEpisodes
          .map((ep) => {
                'seasonNumber': ep.key.season,
                'episodeNumber': ep.key.episode,
                'runtime': ep.runtime,
                'watchedAt': ep.watchedAt.millisecondsSinceEpoch,
                'userRating': ep.userRating,
                'reviewText': ep.reviewText,
                'hasSpoilers': ep.hasSpoilers,
                'loggedAt': ep.loggedAt?.millisecondsSinceEpoch,
              })
          .toList();
    }

    return map;
  }

  static TrackedShow trackedShowFromMap(Map<String, dynamic> data) {
    final showId = (data['showId'] as num?)?.toInt() ?? 0;
    final name = data['name'] as String? ?? '';
    final posterUrl = data['posterUrl'] as String?;
    final status = TrackingStatus.fromName(data['status'] as String? ?? 'watchlist');
    final airedEpisodeCount = (data['airedEpisodeCount'] as num?)?.toInt() ?? 0;
    final episodeRuntime = (data['episodeRuntime'] as num?)?.toInt() ?? 0;
    final showStatusStr = data['showStatus'] as String? ?? 'unknown';
    final showStatus = ShowStatus.values.firstWhere(
      (s) => s.name == showStatusStr,
      orElse: () => ShowStatus.unknown,
    );
    final network = data['network'] as String?;
    final addedAtMs =
        (data['addedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final updatedAtMs = (data['updatedAt'] as num?)?.toInt() ?? addedAtMs;
    final overallUserRating = (data['overallUserRating'] as num?)?.toDouble();
    final reviewText = data['reviewText'] as String?;
    final hasSpoilers = data['hasSpoilers'] as bool? ?? false;
    final loggedAtMs = (data['loggedAt'] as num?)?.toInt();
    final isFavorite = data['isFavorite'] as bool? ?? false;

    return TrackedShow(
      showId: showId,
      name: name,
      posterUrl: posterUrl,
      status: status,
      airedEpisodeCount: airedEpisodeCount,
      episodeRuntime: episodeRuntime,
      showStatus: showStatus,
      network: network,
      addedAt: DateTime.fromMillisecondsSinceEpoch(addedAtMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      overallUserRating: overallUserRating,
      reviewText: reviewText,
      hasSpoilers: hasSpoilers,
      loggedAt: loggedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(loggedAtMs)
          : null,
      isFavorite: isFavorite,
    );
  }

  static List<WatchedEpisode> watchedEpisodesFromMap(
    int showId,
    Map<String, dynamic> data,
  ) {
    final rawList = data['watchedEpisodes'] as List<dynamic>? ?? const [];
    return rawList.whereType<Map<String, dynamic>>().map((epData) {
      final seasonNumber = (epData['seasonNumber'] as num?)?.toInt() ?? 0;
      final episodeNumber = (epData['episodeNumber'] as num?)?.toInt() ?? 0;
      final runtime = (epData['runtime'] as num?)?.toInt() ?? 45;
      final watchedAtMs = (epData['watchedAt'] as num?)?.toInt() ?? 0;
      final userRating = (epData['userRating'] as num?)?.toDouble();
      final reviewText = epData['reviewText'] as String?;
      final hasSpoilers = epData['hasSpoilers'] as bool? ?? false;
      final loggedAtMs = (epData['loggedAt'] as num?)?.toInt();

      return WatchedEpisode(
        showId: showId,
        key: EpisodeKey(seasonNumber, episodeNumber),
        runtime: runtime,
        watchedAt: DateTime.fromMillisecondsSinceEpoch(watchedAtMs),
        userRating: userRating,
        reviewText: reviewText,
        hasSpoilers: hasSpoilers,
        loggedAt: loggedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(loggedAtMs)
            : null,
      );
    }).toList();
  }

  static Map<String, dynamic> userSettingsToMap(UserSettings settings) {
    return {
      'displayName': settings.displayName,
      'username': settings.username,
      'bio': settings.bio,
      'avatarId': settings.avatarId,
      'avatarType': settings.avatarType.name,
      'avatarValue': settings.avatarValue,
      'profileBannerUrl': settings.profileBannerUrl,
      'profileBannerPath': settings.profileBannerPath,
      'followers': settings.followers,
      'following': settings.following,
      'followersCount': settings.followersCount,
      'followingCount': settings.followingCount,
      'ratingDistribution': settings.ratingDistribution,
      'language': settings.language,
      'streamingRegion': settings.streamingRegion,
      'hideSpoilersForUnwatched': settings.hideSpoilersForUnwatched,
      'groupSpecialEpisodes': settings.groupSpecialEpisodes,
      'showOriginalTitles': settings.showOriginalTitles,
      'episodeReleaseReminders': settings.episodeReleaseReminders,
      'reminderHour': settings.reminderHour,
      'reminderMinute': settings.reminderMinute,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static UserSettings profileFromMap(
    Map<String, dynamic> data, {
    UserSettings? fallback,
  }) {
    final base = fallback ?? UserSettings.defaultSettings;
    return UserSettings.fromJson({
      ...base.toJson(),
      ...data,
    });
  }

  static Map<String, dynamic> favoritesToMap(UserSettings settings) {
    return {
      'favoriteShowIds': settings.favoriteShowIds,
      'topFiveFavorites': settings.favoriteShowIds,
      'favoritedShowIds': settings.favoritedShowIds,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static (List<int> topFive, List<int> allFavorites) favoritesFromMap(
    Map<String, dynamic> data,
  ) {
    final rawTop = data['favoriteShowIds'] ?? data['topFiveFavorites'];
    final rawAll = data['favoritedShowIds'];
    final topFive = (rawTop is List)
        ? rawTop.whereType<num>().map((e) => e.toInt()).toList()
        : <int>[];
    final allFavorites = (rawAll is List)
        ? rawAll.whereType<num>().map((e) => e.toInt()).toList()
        : <int>[];
    return (topFive, allFavorites);
  }
}
