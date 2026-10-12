import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Base contract for app-wide localized strings.
abstract class AppLocalizations {
  const AppLocalizations();

  /// Obtains the [AppLocalizations] for the current context.
  ///
  /// If [settingsLanguage] is supplied (from `UserSettings.language`),
  /// it is prioritized to reflect user-selected in-app language overrides.
  static AppLocalizations of(
    BuildContext context, {
    String? settingsLanguage,
  }) {
    if (settingsLanguage != null && settingsLanguage.isNotEmpty) {
      return fromLanguageCode(settingsLanguage);
    }
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        fromLocale(Localizations.maybeLocaleOf(context));
  }

  /// Resolves localizations based on a [Locale].
  static AppLocalizations fromLocale(Locale? locale) {
    return fromLanguageCode(locale?.languageCode);
  }

  /// Resolves localizations based on a language string.
  static AppLocalizations fromLanguageCode(String? language) {
    if (language == null) return const AppLocalizationsEn();
    final code = language.toLowerCase();
    if (code.startsWith('pt')) return const AppLocalizationsPt();
    if (code.startsWith('es')) return const AppLocalizationsEs();
    if (code.startsWith('en')) return const AppLocalizationsEn();
    return const AppLocalizationsEn();
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // App & Navigation
  String get appTitle;
  String get tvShowsBadge;
  String get searchTooltip;

  // Home Screen - Content Sections
  String get trending;
  String get trendingSubtitle;
  String get popular;
  String get popularThisWeek;
  String get popularSubtitle;
  String get topRated;
  String get topRatedSubtitle;
  String get upcoming;
  String get onTheAir;
  String get justPremieredAndNewSeasons;
  String get justPremieredSubtitle;

  // Home Screen - Filters & Tabs
  String get all;
  String get thisWeek;
  String get today;
  String get genreDrama;
  String get genreSciFi;
  String get genreCrime;
  String get genreAnime;
  String get genreComedy;

  // Empty States & Errors
  String get noShowsFound;
  String get noShowsForGenre;
  String get failedToLoad;
  String get failedToLoadPopular;
  String failedToLoadWithMessage(String error);
  String get retry;
  String get reload;
  String get tmdbKeyMissingTitle;
  String get tmdbKeyMissingMessage;
  String get waitingTmdbKey;
  String get demoModeActive;
  String get enableDemoMode;
  String get tryLiveApi;

  // Actions & Buttons
  String get seeAll;
  String get seeLess;

  // Watchlist & Schedule
  String get watchlistTab;
  String get comingSoonTab;
  String get upNextSection;
  String get startWatchingSection;
  String get resumeWatchingSection;

  // Settings & Localization
  String get language;
  String get applicationLanguage;
  String get contentAndLanguagePreferences;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      const AppLocalizationsEn(),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}



/// English strings
class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn();

  @override
  String get appTitle => 'Seriolab';

  @override
  String get tvShowsBadge => 'TV SHOWS';

  @override
  String get searchTooltip => 'Search';

  @override
  String get trending => 'Trending Today';

  @override
  String get trendingSubtitle => 'Trending series across the community';

  @override
  String get popular => 'Popular';

  @override
  String get popularThisWeek => 'Popular This Week';

  @override
  String get popularSubtitle => 'Trending series across the community';

  @override
  String get topRated => 'Top Rated';

  @override
  String get topRatedSubtitle => 'The most acclaimed series and anime of all time';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get onTheAir => 'On The Air';

  @override
  String get justPremieredAndNewSeasons => 'Upcoming / On The Air';

  @override
  String get justPremieredSubtitle => 'Recent episodes and premieres on the air';

  @override
  String get all => 'All';

  @override
  String get thisWeek => 'This Week';

  @override
  String get today => 'Today';

  @override
  String get genreDrama => 'Drama';

  @override
  String get genreSciFi => 'Sci-Fi & Fantasy';

  @override
  String get genreCrime => 'Crime';

  @override
  String get genreAnime => 'Anime';

  @override
  String get genreComedy => 'Comedy';

  @override
  String get noShowsFound => 'No shows found';

  @override
  String get noShowsForGenre => 'No shows found for the selected genre.';

  @override
  String get failedToLoad => 'Failed to load';

  @override
  String get failedToLoadPopular => 'Could not load popular shows';

  @override
  String failedToLoadWithMessage(String error) => 'Failed to load: $error';

  @override
  String get retry => 'Retry';

  @override
  String get reload => 'Retry';

  @override
  String get tmdbKeyMissingTitle => 'TMDB Key Not Configured';

  @override
  String get tmdbKeyMissingMessage =>
      'Configure your TMDB_API_KEY in the .env file in the project root to get real-time data.';

  @override
  String get waitingTmdbKey => 'Waiting for TMDB_API_KEY in .env';

  @override
  String get demoModeActive => 'Demo mode active (local mock data).';

  @override
  String get enableDemoMode => 'Enable Demo Mode (Mock)';

  @override
  String get tryLiveApi => 'Try Live API';

  @override
  String get seeAll => 'See all';

  @override
  String get seeLess => 'Less';

  @override
  String get watchlistTab => 'Watchlist';

  @override
  String get comingSoonTab => 'Coming Soon';

  @override
  String get upNextSection => 'Up Next';

  @override
  String get startWatchingSection => 'Start Watching';

  @override
  String get resumeWatchingSection => 'Resume';

  @override
  String get language => 'Language';

  @override
  String get applicationLanguage => 'App Language';

  @override
  String get contentAndLanguagePreferences => 'Content & Language Preferences';
}

/// Portuguese implementation (English strings)
class AppLocalizationsPt extends AppLocalizationsEn {
  const AppLocalizationsPt();
}

/// Spanish implementation (English strings)
class AppLocalizationsEs extends AppLocalizationsEn {
  const AppLocalizationsEs();
}
