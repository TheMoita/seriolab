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

  /// Resolves localizations based on a language string (e.g. 'pt-PT', 'en-US', 'es-ES').
  static AppLocalizations fromLanguageCode(String? language) {
    if (language == null) return const AppLocalizationsPt();
    final code = language.toLowerCase();
    if (code.startsWith('en')) return const AppLocalizationsEn();
    if (code.startsWith('es')) return const AppLocalizationsEs();
    return const AppLocalizationsPt();
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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['pt', 'en', 'es'].contains(locale.languageCode.toLowerCase());

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations.fromLocale(locale),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Portuguese strings (default)
class AppLocalizationsPt extends AppLocalizations {
  const AppLocalizationsPt();

  @override
  String get appTitle => 'Seriolab';

  @override
  String get tvShowsBadge => 'SÉRIES';

  @override
  String get searchTooltip => 'Procurar';

  @override
  String get trending => 'Tendências de Hoje';

  @override
  String get trendingSubtitle => 'As séries com maior tendência na comunidade';

  @override
  String get popular => 'Populares';

  @override
  String get popularThisWeek => 'Populares Esta Semana';

  @override
  String get popularSubtitle => 'As séries com maior tendência na comunidade';

  @override
  String get topRated => 'Mais Votadas';

  @override
  String get topRatedSubtitle => 'As séries e animes mais aclamados de sempre';

  @override
  String get upcoming => 'A Estrear';

  @override
  String get onTheAir => 'Em Exibição';

  @override
  String get justPremieredAndNewSeasons => 'A Estrear / Em Exibição';

  @override
  String get justPremieredSubtitle => 'Episódios e estreias recentes em exibição';

  @override
  String get all => 'Tudo';

  @override
  String get thisWeek => 'Esta Semana';

  @override
  String get today => 'Hoje';

  @override
  String get genreDrama => 'Drama';

  @override
  String get genreSciFi => 'Sci-Fi & Fantasia';

  @override
  String get genreCrime => 'Crime';

  @override
  String get genreAnime => 'Anime';

  @override
  String get genreComedy => 'Comédia';

  @override
  String get noShowsFound => 'Nenhuma série encontrada';

  @override
  String get noShowsForGenre => 'Nenhuma série encontrada para o género selecionado.';

  @override
  String get failedToLoad => 'Erro ao carregar dados';

  @override
  String get failedToLoadPopular => 'Não foi possível carregar as séries populares';

  @override
  String failedToLoadWithMessage(String error) => 'Erro ao carregar dados: $error';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get reload => 'Tentar novamente';

  @override
  String get tmdbKeyMissingTitle => 'Chave TMDB Não Configurada';

  @override
  String get tmdbKeyMissingMessage =>
      'Configura a tua TMDB_API_KEY no ficheiro .env na raiz do projeto para obteres dados em tempo real.';

  @override
  String get waitingTmdbKey => 'A aguardar TMDB_API_KEY no .env';

  @override
  String get demoModeActive => 'Modo de demonstração ativo (dados locais mock).';

  @override
  String get enableDemoMode => 'Ativar Modo Demonstração (Mock)';

  @override
  String get tryLiveApi => 'Tentar API Real';

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get seeLess => 'Menos';

  @override
  String get watchlistTab => 'Lista para Assistir';

  @override
  String get comingSoonTab => 'Brevemente';

  @override
  String get upNextSection => 'Ver a Seguir';

  @override
  String get startWatchingSection => 'Começar a Ver';

  @override
  String get resumeWatchingSection => 'Retomar';
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
}

/// Spanish strings
class AppLocalizationsEs extends AppLocalizations {
  const AppLocalizationsEs();

  @override
  String get appTitle => 'Seriolab';

  @override
  String get tvShowsBadge => 'SERIES';

  @override
  String get searchTooltip => 'Buscar';

  @override
  String get trending => 'Tendencias de Hoy';

  @override
  String get trendingSubtitle => 'Las series con mayor tendencia en la comunidad';

  @override
  String get popular => 'Populares';

  @override
  String get popularThisWeek => 'Populares Esta Semana';

  @override
  String get popularSubtitle => 'Las series con mayor tendencia en la comunidad';

  @override
  String get topRated => 'Más Votadas';

  @override
  String get topRatedSubtitle => 'Las series y animes más aclamados de siempre';

  @override
  String get upcoming => 'A Estrenar';

  @override
  String get onTheAir => 'En Emisión';

  @override
  String get justPremieredAndNewSeasons => 'A Estrenar / En Emisión';

  @override
  String get justPremieredSubtitle => 'Episodios y estrenos recientes en emisión';

  @override
  String get all => 'Todo';

  @override
  String get thisWeek => 'Esta Semana';

  @override
  String get today => 'Hoy';

  @override
  String get genreDrama => 'Drama';

  @override
  String get genreSciFi => 'Ciencia Ficción y Fantasía';

  @override
  String get genreCrime => 'Crimen';

  @override
  String get genreAnime => 'Anime';

  @override
  String get genreComedy => 'Comedia';

  @override
  String get noShowsFound => 'No se encontraron series';

  @override
  String get noShowsForGenre => 'No se encontraron series para el género seleccionado.';

  @override
  String get failedToLoad => 'Error al cargar datos';

  @override
  String get failedToLoadPopular => 'No fue posible cargar las series populares';

  @override
  String failedToLoadWithMessage(String error) => 'Error al cargar: $error';

  @override
  String get retry => 'Reintentar';

  @override
  String get reload => 'Reintentar';

  @override
  String get tmdbKeyMissingTitle => 'Clave TMDB No Configurada';

  @override
  String get tmdbKeyMissingMessage =>
      'Configura tu TMDB_API_KEY en el archivo .env en la raíz del proyecto para obtener datos en tiempo real.';

  @override
  String get waitingTmdbKey => 'Esperando TMDB_API_KEY en .env';

  @override
  String get demoModeActive => 'Modo de demostración activo (datos locales mock).';

  @override
  String get enableDemoMode => 'Activar Modo Demostración (Mock)';

  @override
  String get tryLiveApi => 'Probar API Real';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get seeLess => 'Menos';

  @override
  String get watchlistTab => 'Lista para Ver';

  @override
  String get comingSoonTab => 'Próximamente';

  @override
  String get upNextSection => 'Siguiente';

  @override
  String get startWatchingSection => 'Empezar a Ver';

  @override
  String get resumeWatchingSection => 'Reanudar';
}
