import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/local_storage_utils.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../shows/domain/entities/episode.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/entities/tracking_state.dart';
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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _watchlistSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _librarySubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _watchedEpisodesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _favoritesSubscription;

  final Set<void Function(TrackingSnapshot snapshot)> _trackingListeners = {};

  /// Registers a reactive callback triggered whenever cloud library changes are synced down.
  void Function() addTrackingListener(void Function(TrackingSnapshot snapshot) listener) {
    _trackingListeners.add(listener);
    return () => _trackingListeners.remove(listener);
  }

  void _notifyTrackingListeners(TrackingSnapshot snapshot) {
    for (final listener in List.of(_trackingListeners)) {
      try {
        listener(snapshot);
      } catch (e) {
        debugPrint('FirestoreSyncService: tracking listener notification note: $e');
      }
    }
  }

  /// Resolves the authenticated user ID from active state or Firebase Auth.
  String? get _resolvedUid {
    if (_activeUid != null && _activeUid!.trim().isNotEmpty) return _activeUid;
    if (Firebase.apps.isNotEmpty) {
      try {
        final u = FirebaseAuth.instance.currentUser;
        if (u != null && u.uid.trim().isNotEmpty) return u.uid;
      } catch (_) {}
    }
    return null;
  }

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
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    _watchlistSubscription?.cancel();
    _watchlistSubscription = null;
    _librarySubscription?.cancel();
    _librarySubscription = null;
    _watchedEpisodesSubscription?.cancel();
    _watchedEpisodesSubscription = null;
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

      // 1. Maintain root user record (merge: true)
      try {
        await userDocRef.set({
          'uid': uid,
          'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('FirestoreSyncService: root doc set note: $e');
      }

      // 2. Fetch root document first to prevent overwriting cloud state with empty defaults
      DocumentSnapshot<Map<String, dynamic>>? rootSnapshot;
      try {
        rootSnapshot = await userDocRef.get();
      } catch (e) {
        debugPrint('FirestoreSyncService: root doc get error: $e');
      }
      final rootData = rootSnapshot?.data();

      // 3. Profile Sync: check root doc 'profile' map or direct fields
      Map<String, dynamic>? profileData;
      if (rootData != null && rootData['profile'] is Map) {
        profileData = Map<String, dynamic>.from(rootData['profile'] as Map);
      } else if (rootData != null &&
          (rootData['avatarUrl'] != null ||
              rootData['bannerUrl'] != null ||
              rootData['profileBannerUrl'] != null ||
              rootData['bio'] != null ||
              rootData['username'] != null)) {
        profileData = Map<String, dynamic>.from(rootData);
      }

      // If not present in root doc, check subcollection users/{uid}/profile/info
      if (profileData == null) {
        final profileDocRef = userDocRef.collection('profile').doc('info');
        try {
          final profileSnapshot = await profileDocRef.get();
          if (profileSnapshot.exists && profileSnapshot.data() != null) {
            profileData = profileSnapshot.data()!;
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: Profile subcollection get note: $e');
        }
      }

      if (profileData != null && profileData.isNotEmpty) {
        final remoteSettings = profileFromMap(profileData);
        await _settingsRepo.saveSettings(remoteSettings);
        settingsNotifier?.syncFromRemote(remoteSettings);
      } else {
        // Only upload local settings to Firestore if NO remote profile existed
        final localSettings = await _settingsRepo.getSettings();
        await syncUserProfile(localSettings, uid: uid);
      }

      // 4. Favorites Sync: check root doc 'favorites' map or direct list fields
      Map<String, dynamic>? favData;
      if (rootData != null && rootData['favorites'] is Map) {
        favData = Map<String, dynamic>.from(rootData['favorites'] as Map);
      } else if (rootData != null &&
          (rootData['topFiveIds'] != null ||
              rootData['favoriteSeriesIds'] != null ||
              rootData['favoriteShowIds'] != null)) {
        favData = Map<String, dynamic>.from(rootData);
      }

      // If not present in root doc, check subcollection users/{uid}/favorites/top_five
      if (favData == null) {
        final favDocRef = userDocRef.collection('favorites').doc('top_five');
        try {
          final favSnapshot = await favDocRef.get();
          if (favSnapshot.exists && favSnapshot.data() != null) {
            favData = favSnapshot.data()!;
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: Favorites subcollection get note: $e');
        }
      }

      if (favData != null && favData.isNotEmpty) {
        final (topFive, allFavs) = favoritesFromMap(favData);
        settingsNotifier?.syncFavoritesFromRemote(topFive, allFavs);
      } else {
        // Only upload local favorites to Firestore if NO remote favorites existed
        final localSettings = await _settingsRepo.getSettings();
        await syncFavorites(localSettings, uid: uid);
      }

      // 4. Watchlist & Library Sync (users/{uid}/library and users/{uid}/watchlist)
      final watchlistCol = userDocRef.collection('watchlist');
      final libraryCol = userDocRef.collection('library');
      try {
        final watchlistSnapshot = await watchlistCol.get();
        final librarySnapshot = await libraryCol.get();
        final remoteDocs = <String, Map<String, dynamic>>{};
        for (final doc in watchlistSnapshot.docs) {
          remoteDocs[doc.id] = doc.data();
        }
        for (final doc in librarySnapshot.docs) {
          remoteDocs[doc.id] = doc.data();
        }

        final localSnapshot = await _trackingRepo.load();
        final localWatchedMap = <int, List<WatchedEpisode>>{};
        for (final ep in localSnapshot.episodes) {
          localWatchedMap.putIfAbsent(ep.showId, () => []).add(ep);
        }

        if (remoteDocs.isNotEmpty) {
          final remoteShowIds = <int>{};
          for (final entry in remoteDocs.entries) {
            final data = entry.value;
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
              final showMap = trackedShowToMap(
                localShow,
                watchedEpisodes: localWatchedMap[localShow.showId] ?? const [],
              );
              await watchlistCol.doc('${localShow.showId}').set(showMap);
              await libraryCol.doc('${localShow.showId}').set(showMap);
            }
          }

          final mergedSnapshot = await _trackingRepo.load();
          trackingController?.syncFromRemote(mergedSnapshot);
          _notifyTrackingListeners(mergedSnapshot);
        } else if (localSnapshot.shows.isNotEmpty) {
          // Upload local shows to Firestore
          for (final localShow in localSnapshot.shows) {
            final showMap = trackedShowToMap(
              localShow,
              watchedEpisodes: localWatchedMap[localShow.showId] ?? const [],
            );
            await watchlistCol.doc('${localShow.showId}').set(showMap);
            await libraryCol.doc('${localShow.showId}').set(showMap);
          }
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Watchlist/Library sync note: $e');
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

    // Root user document listener (profile & favorites)
    _userDocSubscription = userDocRef.snapshots().listen(
      (docSnap) async {
        if (_isSyncingDown || !docSnap.exists || docSnap.data() == null) return;
        final data = docSnap.data()!;
        _isSyncingDown = true;
        try {
          if (data['profile'] is Map) {
            final remoteSettings =
                profileFromMap(Map<String, dynamic>.from(data['profile'] as Map));
            await _settingsRepo.saveSettings(remoteSettings);
            settingsNotifier?.syncFromRemote(remoteSettings);
          }
          if (data['favorites'] is Map) {
            final (topFive, allFavs) =
                favoritesFromMap(Map<String, dynamic>.from(data['favorites'] as Map));
            settingsNotifier?.syncFavoritesFromRemote(topFive, allFavs);
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: user doc live listener error: $e');
        } finally {
          _isSyncingDown = false;
        }
      },
      onError: (e) {
        debugPrint('FirestoreSyncService: user doc subscription error: $e');
      },
    );

    Future<void> handleLibrarySnapshotChanges(
      QuerySnapshot<Map<String, dynamic>> querySnap,
    ) async {
      if (_isSyncingDown) return;
      _isSyncingDown = true;
      try {
        var hasChanges = false;
        for (final docChange in querySnap.docChanges) {
          hasChanges = true;
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
        if (hasChanges) {
          final updated = await _trackingRepo.load();
          trackingController?.syncFromRemote(updated);
          _notifyTrackingListeners(updated);
        }
      } catch (e) {
        debugPrint('FirestoreSyncService: Library live listener error: $e');
      } finally {
        _isSyncingDown = false;
      }
    }

    // Watchlist listener
    _watchlistSubscription = userDocRef
        .collection('watchlist')
        .snapshots()
        .listen(
          handleLibrarySnapshotChanges,
          onError: (e) {
            debugPrint('FirestoreSyncService: Watchlist subscription error: $e');
          },
        );

    // Library listener (mirrored collection users/{uid}/library)
    _librarySubscription = userDocRef
        .collection('library')
        .snapshots()
        .listen(
          handleLibrarySnapshotChanges,
          onError: (e) {
            debugPrint('FirestoreSyncService: Library subscription error: $e');
          },
        );

    // Watched episodes subcollection listener (users/{uid}/watched_episodes)
    _watchedEpisodesSubscription = userDocRef
        .collection('watched_episodes')
        .snapshots()
        .listen(
      (querySnap) async {
        if (_isSyncingDown) return;
        _isSyncingDown = true;
        try {
          var hasEpisodeChanges = false;
          for (final docChange in querySnap.docChanges) {
            hasEpisodeChanges = true;
            final data = docChange.doc.data();
            final showId = (data?['showId'] as num?)?.toInt();
            final season = (data?['seasonNumber'] as num?)?.toInt();
            final episode = (data?['episodeNumber'] as num?)?.toInt();
            if (showId != null && season != null && episode != null) {
              final key = EpisodeKey(season, episode);
              if (docChange.type == DocumentChangeType.removed) {
                await _trackingRepo.unmarkWatched(showId, [key]);
              } else if (data != null) {
                final runtime = (data['runtime'] as num?)?.toInt() ?? 45;
                final watchedAtMs = (data['watchedAt'] as num?)?.toInt() ?? 0;
                final userRating = (data['userRating'] as num?)?.toDouble();
                final reviewText = data['reviewText'] as String?;
                final hasSpoilers = data['hasSpoilers'] as bool? ?? false;
                final loggedAtMs = (data['loggedAt'] as num?)?.toInt();

                await _trackingRepo.markWatched([
                  WatchedEpisode(
                    showId: showId,
                    key: key,
                    runtime: runtime,
                    watchedAt: DateTime.fromMillisecondsSinceEpoch(watchedAtMs),
                    userRating: userRating,
                    reviewText: reviewText,
                    hasSpoilers: hasSpoilers,
                    loggedAt: loggedAtMs != null
                        ? DateTime.fromMillisecondsSinceEpoch(loggedAtMs)
                        : null,
                  ),
                ]);
              }
            }
          }
          if (hasEpisodeChanges) {
            final updated = await _trackingRepo.load();
            trackingController?.syncFromRemote(updated);
            _notifyTrackingListeners(updated);
          }
        } catch (e) {
          debugPrint('FirestoreSyncService: watched_episodes live listener error: $e');
        } finally {
          _isSyncingDown = false;
        }
      },
      onError: (e) {
        debugPrint('FirestoreSyncService: watched_episodes subscription error: $e');
      },
    );

    // Profile listener (subcollection mirror)
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

    // Favorites listener (subcollection mirror)
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

  /// Real-time stream of tracked shows in the user's library.
  Stream<List<TrackedShow>> streamUserLibrary(String uid) {
    final firestore = _firestore;
    if (firestore == null || uid.trim().isEmpty) {
      return Stream.fromFuture(_trackingRepo.load().then((s) => s.shows));
    }
    return firestore
        .collection('users')
        .doc(uid)
        .collection('library')
        .snapshots()
        .asyncMap((snap) async {
          if (snap.docs.isNotEmpty) {
            return snap.docs.map((d) => trackedShowFromMap(d.data())).toList();
          }
          final fallbackSnap = await firestore
              .collection('users')
              .doc(uid)
              .collection('watchlist')
              .get();
          if (fallbackSnap.docs.isNotEmpty) {
            return fallbackSnap.docs
                .map((d) => trackedShowFromMap(d.data()))
                .toList();
          }
          final local = await _trackingRepo.load();
          return local.shows;
        });
  }

  /// Real-time stream of aggregated UserStats.
  Stream<UserStats> streamUserStats(String uid) {
    final firestore = _firestore;
    if (firestore == null || uid.trim().isEmpty) {
      return Stream.fromFuture(
        _trackingRepo.load().then((s) => TrackingState.fromSnapshot(s).stats),
      );
    }
    return firestore
        .collection('users')
        .doc(uid)
        .collection('library')
        .snapshots()
        .asyncMap((_) async {
          final snapshot = await _trackingRepo.load();
          return TrackingState.fromSnapshot(snapshot).stats;
        });
  }

  /// Syncs an individual show and its watched episodes to `users/{uid}/watchlist/{seriesId}`
  /// and `users/{uid}/library/{seriesId}`.
  Future<void> syncTrackedShow(
    TrackedShow show, {
    List<WatchedEpisode>? watchedEpisodes,
    String? uid,
  }) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _resolvedUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final docMap = trackedShowToMap(show, watchedEpisodes: watchedEpisodes);

      // Persist to watchlist collection
      final watchlistDocRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('watchlist')
          .doc('${show.showId}');
      await watchlistDocRef.set(
        docMap,
        SetOptions(merge: true),
      );

      // Mirror to library collection
      final libraryDocRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('library')
          .doc('${show.showId}');
      await libraryDocRef.set(
        docMap,
        SetOptions(merge: true),
      );

      // Mirror to users/{uid}/watched_episodes collection
      if (watchedEpisodes != null && watchedEpisodes.isNotEmpty) {
        final batch = firestore.batch();
        for (final ep in watchedEpisodes) {
          final epDocRef = firestore
              .collection('users')
              .doc(effectiveUid)
              .collection('watched_episodes')
              .doc('${show.showId}_${ep.key.season}_${ep.key.episode}');
          batch.set(
            epDocRef,
            {
              'showId': show.showId,
              'seasonNumber': ep.key.season,
              'episodeNumber': ep.key.episode,
              'runtime': ep.runtime,
              'watchedAt': ep.watchedAt.millisecondsSinceEpoch,
              if (ep.userRating != null) 'userRating': ep.userRating,
              if (ep.reviewText != null) 'reviewText': ep.reviewText,
              'hasSpoilers': ep.hasSpoilers,
              if (ep.loggedAt != null)
                'loggedAt': ep.loggedAt!.millisecondsSinceEpoch,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('FirestoreSyncService: Error syncing show ${show.showId}: $e');
    }
  }

  /// Removes an individual show from `users/{uid}/watchlist/{seriesId}` and `library`.
  Future<void> deleteTrackedShow(int showId, {String? uid}) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _resolvedUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final watchlistDocRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('watchlist')
          .doc('$showId');
      await watchlistDocRef.delete();

      final libraryDocRef = firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('library')
          .doc('$showId');
      await libraryDocRef.delete();

      try {
        final watchedQuery = await firestore
            .collection('users')
            .doc(effectiveUid)
            .collection('watched_episodes')
            .where('showId', isEqualTo: showId)
            .get();
        if (watchedQuery.docs.isNotEmpty) {
          final batch = firestore.batch();
          for (final doc in watchedQuery.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('FirestoreSyncService: Error deleting show $showId: $e');
    }
  }

  /// Syncs user profile details to `users/{uid}` and `users/{uid}/profile/info`.
  Future<void> syncUserProfile(UserSettings settings, {String? uid}) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _resolvedUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final userDocRef = firestore.collection('users').doc(effectiveUid);
      final profileMap = userSettingsToMap(settings);

      // 1. Primary source of truth: root document users/{uid}
      await userDocRef.set({
        'uid': effectiveUid,
        'profile': profileMap,
        'avatarUrl': profileMap['avatarUrl'],
        'avatarType': profileMap['avatarType'],
        'avatarValue': profileMap['avatarValue'],
        'bannerUrl': profileMap['bannerUrl'],
        'profileBannerUrl': profileMap['profileBannerUrl'],
        'profileBannerPath': profileMap['profileBannerPath'],
        'bio': profileMap['bio'],
        'displayName': profileMap['displayName'],
        'username': profileMap['username'],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      // 2. Subcollection mirror for full backward compatibility
      final docRef = userDocRef.collection('profile').doc('info');
      await docRef.set(profileMap, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreSyncService: Error syncing profile: $e');
    }
  }

  /// Syncs top 5 and favorites to `users/{uid}` and `users/{uid}/favorites/top_five`.
  Future<void> syncFavorites(UserSettings settings, {String? uid}) async {
    final firestore = _firestore;
    final effectiveUid = uid ?? _resolvedUid;
    if (firestore == null || effectiveUid == null || effectiveUid.trim().isEmpty) {
      return;
    }

    try {
      final userDocRef = firestore.collection('users').doc(effectiveUid);
      final favMap = favoritesToMap(settings);

      // 1. Primary source of truth: root document users/{uid}
      await userDocRef.set({
        'uid': effectiveUid,
        'favorites': favMap,
        'topFiveIds': favMap['topFiveIds'],
        'favoriteSeriesIds': favMap['favoriteSeriesIds'],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      // 2. Subcollection mirror for full backward compatibility
      final docRef = userDocRef.collection('favorites').doc('top_five');
      await docRef.set(favMap, SetOptions(merge: true));
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
    final bannerPathFilename = settings.profileBannerPath != null
        ? LocalStorageUtils.extractFilename(settings.profileBannerPath!)
        : null;
    final avatarValueNormalized = settings.avatarType == AvatarType.localFile &&
            settings.avatarValue != null
        ? LocalStorageUtils.extractFilename(settings.avatarValue!)
        : settings.avatarValue;

    return {
      'displayName': settings.displayName,
      'username': settings.username,
      'bio': settings.bio,
      'avatarId': settings.avatarId,
      'avatarType': settings.avatarType.name,
      'avatarValue': avatarValueNormalized,
      'avatarUrl':
          settings.avatarType == AvatarType.networkUrl ? settings.avatarValue : null,
      'profileBannerUrl': settings.profileBannerUrl,
      'bannerUrl': settings.profileBannerUrl,
      'profileBannerPath': bannerPathFilename,
      'bannerPath': bannerPathFilename,
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
    final map = Map<String, dynamic>.from(data);

    if (map['bannerUrl'] != null && map['profileBannerUrl'] == null) {
      map['profileBannerUrl'] = map['bannerUrl'];
    }
    if (map['bannerPath'] != null && map['profileBannerPath'] == null) {
      map['profileBannerPath'] = map['bannerPath'];
    }
    if (map['avatarUrl'] != null && map['avatarValue'] == null) {
      map['avatarValue'] = map['avatarUrl'];
      map['avatarType'] = AvatarType.networkUrl.name;
    }
    if (map['topFiveIds'] != null && map['favoriteShowIds'] == null) {
      map['favoriteShowIds'] = map['topFiveIds'];
    }
    if (map['favoriteSeriesIds'] != null && map['favoritedShowIds'] == null) {
      map['favoritedShowIds'] = map['favoriteSeriesIds'];
    }

    return UserSettings.fromJson({
      ...base.toJson(),
      ...map,
    });
  }

  static Map<String, dynamic> favoritesToMap(UserSettings settings) {
    return {
      'favoriteShowIds': settings.favoriteShowIds,
      'topFiveFavorites': settings.favoriteShowIds,
      'topFiveIds': settings.favoriteShowIds,
      'favoritedShowIds': settings.favoritedShowIds,
      'favoriteSeriesIds': settings.favoritedShowIds,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static (List<int> topFive, List<int> allFavorites) favoritesFromMap(
    Map<String, dynamic> data,
  ) {
    final rawTop =
        data['topFiveIds'] ?? data['favoriteShowIds'] ?? data['topFiveFavorites'];
    final rawAll = data['favoriteSeriesIds'] ?? data['favoritedShowIds'];
    final topFive = (rawTop is List)
        ? rawTop.whereType<num>().map((e) => e.toInt()).toList()
        : <int>[];
    final allFavorites = (rawAll is List)
        ? rawAll.whereType<num>().map((e) => e.toInt()).toList()
        : <int>[];
    return (topFive, allFavorites);
  }
}
