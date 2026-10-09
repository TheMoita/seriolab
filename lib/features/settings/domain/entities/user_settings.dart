import 'package:flutter/material.dart';

/// Preset avatar definitions with thematic series and cinema inspirations.
@immutable
class SeriolabAvatar {
  const SeriolabAvatar({
    required this.id,
    required this.name,
    required this.seriesInspiration,
    required this.icon,
    required this.gradientColors,
  });

  final String id;
  final String name;
  final String seriesInspiration;
  final IconData icon;
  final List<Color> gradientColors;

  static const List<SeriolabAvatar> presets = [
    SeriolabAvatar(
      id: 'tv_retro',
      name: 'TV Retro',
      seriesInspiration: 'Clássicos & The Twilight Zone',
      icon: Icons.tv_rounded,
      gradientColors: [Color(0xFF7C5CFC), Color(0xFF4338CA)],
    ),
    SeriolabAvatar(
      id: 'mask',
      name: 'Máscara',
      seriesInspiration: 'La Casa de Papel & Watchmen',
      icon: Icons.theater_comedy_rounded,
      gradientColors: [Color(0xFFEF4444), Color(0xFF991B1B)],
    ),
    SeriolabAvatar(
      id: 'fedora',
      name: 'Chapéu Fedora',
      seriesInspiration: 'Breaking Bad & Peaky Blinders',
      icon: Icons.shield_moon_rounded,
      gradientColors: [Color(0xFFF59E0B), Color(0xFF78350F)],
    ),
    SeriolabAvatar(
      id: 'throne',
      name: 'Trono de Ferro',
      seriesInspiration: 'House of the Dragon & GoT',
      icon: Icons.castle_rounded,
      gradientColors: [Color(0xFFD97706), Color(0xFF334155)],
    ),
    SeriolabAvatar(
      id: 'walkie',
      name: 'Walkie-talkie',
      seriesInspiration: 'Stranger Things & Dark',
      icon: Icons.cell_tower_rounded,
      gradientColors: [Color(0xFFFB923C), Color(0xFF0F766E)],
    ),
    SeriolabAvatar(
      id: 'clapper',
      name: 'Claquete',
      seriesInspiration: 'Produção de TV & HBO',
      icon: Icons.movie_rounded,
      gradientColors: [Color(0xFFE2E8F0), Color(0xFF6366F1)],
    ),
    SeriolabAvatar(
      id: 'dragon',
      name: 'Dragão',
      seriesInspiration: 'Targaryen & Épicos de Fantasia',
      icon: Icons.local_fire_department_rounded,
      gradientColors: [Color(0xFFDC2626), Color(0xFFF97316)],
    ),
    SeriolabAvatar(
      id: 'cyber',
      name: 'Nave Sci-Fi',
      seriesInspiration: 'Severance & The Expanse',
      icon: Icons.rocket_launch_rounded,
      gradientColors: [Color(0xFF38BDF8), Color(0xFF1E1B4B)],
    ),
    SeriolabAvatar(
      id: 'detective',
      name: 'Investigador',
      seriesInspiration: 'Sherlock & True Detective',
      icon: Icons.search_rounded,
      gradientColors: [Color(0xFF10B981), Color(0xFF064E3B)],
    ),
    SeriolabAvatar(
      id: 'crown',
      name: 'Coroa Real',
      seriesInspiration: 'The Crown & Succession',
      icon: Icons.emoji_events_rounded,
      gradientColors: [Color(0xFFFBBF24), Color(0xFF6D28D9)],
    ),
    SeriolabAvatar(
      id: 'heart',
      name: 'Coração de Drama',
      seriesInspiration: 'Grey\'s Anatomy & This Is Us',
      icon: Icons.favorite_rounded,
      gradientColors: [Color(0xFFEC4899), Color(0xFF831843)],
    ),
    SeriolabAvatar(
      id: 'iris',
      name: 'Electric Iris',
      seriesInspiration: 'Identidade Oficial Seriolab',
      icon: Icons.movie_filter_rounded,
      gradientColors: [Color(0xFF7C5CFC), Color(0xFF38BDF8)],
    ),
  ];

  static SeriolabAvatar getById(String id) {
    return presets.firstWhere(
      (a) => a.id == id,
      orElse: () => presets.first,
    );
  }
}

/// Avatar source types supported in Seriolab.
enum AvatarType {
  preset,
  localFile,
  networkUrl;

  static AvatarType fromString(String? val) {
    if (val == null) return AvatarType.preset;
    for (final type in AvatarType.values) {
      if (type.name == val) return type;
    }
    return AvatarType.preset;
  }
}

/// User profile and app preferences model.
@immutable
class UserSettings {
  const UserSettings({
    required this.displayName,
    required this.username,
    required this.bio,
    required this.avatarId,
    this.avatarType = AvatarType.preset,
    this.avatarValue,
    required this.language,
    required this.streamingRegion,
    required this.hideSpoilersForUnwatched,
    required this.groupSpecialEpisodes,
    required this.episodeReleaseReminders,
    required this.reminderHour,
    required this.reminderMinute,
    this.showOriginalTitles = false,
    this.favoriteShowIds = const [1396, 95396, 100088, 126308, 94605],
    this.ratingDistribution = defaultRatingDistribution,
  });

  // Account & Profile
  final String displayName;
  final String username;
  final String bio;
  final String avatarId;
  final AvatarType avatarType;
  final String? avatarValue;

  String get effectiveAvatarValue => avatarValue ?? avatarId;

  // Content & Language
  final String language; // 'pt-PT', 'pt-BR', 'en-US', 'es-ES' or 'pt', 'en', 'es'
  final String streamingRegion; // 'PT', 'BR', 'US', 'GB', 'ES', etc.

  // Anti-spoiler & Display
  final bool hideSpoilersForUnwatched;
  final bool groupSpecialEpisodes;
  final bool showOriginalTitles;

  /// Returns standard TMDB language code (e.g., 'pt-PT', 'pt-BR', 'en-US', 'es-ES').
  String get tmdbLanguageCode {
    if (language.contains('-')) return language;
    return switch (language.toLowerCase()) {
      'pt' => streamingRegion == 'BR' ? 'pt-BR' : 'pt-PT',
      'en' => 'en-US',
      'es' => 'es-ES',
      _ => 'pt-PT',
    };
  }

  // Notifications
  final bool episodeReleaseReminders;
  final int reminderHour;
  final int reminderMinute;

  // Favorites & Ratings Breakdown
  final List<int> favoriteShowIds;
  final Map<String, int> ratingDistribution;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  String get formattedReminderTime {
    final h = reminderHour.toString().padLeft(2, '0');
    final m = reminderMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int get totalRatingsCount =>
      ratingDistribution.values.fold(0, (sum, count) => sum + count);

  double get averageRating {
    final total = totalRatingsCount;
    if (total == 0) return 0.0;
    var totalPoints = 0.0;
    ratingDistribution.forEach((scoreStr, count) {
      final score = double.tryParse(scoreStr) ?? 0.0;
      totalPoints += score * count;
    });
    return totalPoints / total;
  }

  static const Map<String, int> defaultRatingDistribution = {
    '1.0': 0,
    '1.5': 0,
    '2.0': 0,
    '2.5': 1,
    '3.0': 0,
    '3.5': 1,
    '4.0': 2,
    '4.5': 1,
    '5.0': 3,
    '5.5': 2,
    '6.0': 4,
    '6.5': 5,
    '7.0': 7,
    '7.5': 9,
    '8.0': 12,
    '8.5': 15,
    '9.0': 11,
    '9.5': 6,
    '10.0': 4,
  };

  static const UserSettings defaultSettings = UserSettings(
    displayName: 'Afonso Dias',
    username: 'afonsodias',
    bio: 'Maratonista de séries e entusiasta de ficção científica & drama.',
    avatarId: 'tv_retro',
    avatarType: AvatarType.preset,
    avatarValue: 'tv_retro',
    language: 'pt',
    streamingRegion: 'PT',
    hideSpoilersForUnwatched: true,
    groupSpecialEpisodes: true,
    showOriginalTitles: false,
    episodeReleaseReminders: true,
    reminderHour: 20,
    reminderMinute: 0,
    favoriteShowIds: [1396, 95396, 100088, 126308, 94605],
    ratingDistribution: defaultRatingDistribution,
  );

  UserSettings copyWith({
    String? displayName,
    String? username,
    String? bio,
    String? avatarId,
    AvatarType? avatarType,
    String? avatarValue,
    String? language,
    String? streamingRegion,
    bool? hideSpoilersForUnwatched,
    bool? groupSpecialEpisodes,
    bool? showOriginalTitles,
    bool? episodeReleaseReminders,
    int? reminderHour,
    int? reminderMinute,
    List<int>? favoriteShowIds,
    Map<String, int>? ratingDistribution,
  }) {
    return UserSettings(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarId: avatarId ?? this.avatarId,
      avatarType: avatarType ?? this.avatarType,
      avatarValue: avatarValue ?? this.avatarValue,
      language: language ?? this.language,
      streamingRegion: streamingRegion ?? this.streamingRegion,
      hideSpoilersForUnwatched:
          hideSpoilersForUnwatched ?? this.hideSpoilersForUnwatched,
      groupSpecialEpisodes: groupSpecialEpisodes ?? this.groupSpecialEpisodes,
      showOriginalTitles: showOriginalTitles ?? this.showOriginalTitles,
      episodeReleaseReminders:
          episodeReleaseReminders ?? this.episodeReleaseReminders,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      favoriteShowIds: favoriteShowIds ?? this.favoriteShowIds,
      ratingDistribution: ratingDistribution ?? this.ratingDistribution,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'username': username,
      'bio': bio,
      'avatarId': avatarId,
      'avatarType': avatarType.name,
      'avatarValue': avatarValue,
      'language': language,
      'streamingRegion': streamingRegion,
      'hideSpoilersForUnwatched': hideSpoilersForUnwatched,
      'groupSpecialEpisodes': groupSpecialEpisodes,
      'showOriginalTitles': showOriginalTitles,
      'episodeReleaseReminders': episodeReleaseReminders,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'favoriteShowIds': favoriteShowIds,
      'ratingDistribution': ratingDistribution,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    List<int> parseFavorites(dynamic raw) {
      if (raw is List) {
        return raw.whereType<num>().map((e) => e.toInt()).toList();
      }
      return defaultSettings.favoriteShowIds;
    }

    Map<String, int> parseDistribution(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return defaultSettings.ratingDistribution;
    }

    final avatarType = AvatarType.fromString(json['avatarType'] as String?);
    final avatarId =
        json['avatarId'] as String? ?? defaultSettings.avatarId;
    final avatarValue = json['avatarValue'] as String? ??
        (avatarType == AvatarType.preset ? avatarId : null);

    return UserSettings(
      displayName:
          json['displayName'] as String? ?? defaultSettings.displayName,
      username: json['username'] as String? ?? defaultSettings.username,
      bio: json['bio'] as String? ?? defaultSettings.bio,
      avatarId: avatarId,
      avatarType: avatarType,
      avatarValue: avatarValue,
      language: json['language'] as String? ?? defaultSettings.language,
      streamingRegion:
          json['streamingRegion'] as String? ?? defaultSettings.streamingRegion,
      hideSpoilersForUnwatched: json['hideSpoilersForUnwatched'] as bool? ??
          defaultSettings.hideSpoilersForUnwatched,
      groupSpecialEpisodes: json['groupSpecialEpisodes'] as bool? ??
          defaultSettings.groupSpecialEpisodes,
      showOriginalTitles: json['showOriginalTitles'] as bool? ??
          defaultSettings.showOriginalTitles,
      episodeReleaseReminders: json['episodeReleaseReminders'] as bool? ??
          defaultSettings.episodeReleaseReminders,
      reminderHour:
          json['reminderHour'] as int? ?? defaultSettings.reminderHour,
      reminderMinute:
          json['reminderMinute'] as int? ?? defaultSettings.reminderMinute,
      favoriteShowIds: parseFavorites(json['favoriteShowIds']),
      ratingDistribution: parseDistribution(json['ratingDistribution']),
    );
  }
}
