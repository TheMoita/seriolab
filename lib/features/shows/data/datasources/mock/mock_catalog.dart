import '../../../domain/entities/episode.dart';
import '../../../domain/entities/genre.dart';

/// Season definition for the offline demo catalogue.
///
/// Seasons are either anchored to an absolute premiere date (past seasons) or
/// relative to *today* ([premiereOffsetDays]) so the release calendar always
/// has upcoming content regardless of when the app is opened.
class MockSeasonSeed {
  const MockSeasonSeed.at(
    DateTime this.premiere, {
    required this.episodes,
    this.intervalDays = 7,
    this.titles = const [],
  }) : premiereOffsetDays = null;

  const MockSeasonSeed.relative(
    int this.premiereOffsetDays, {
    required this.episodes,
    this.intervalDays = 7,
    this.titles = const [],
  }) : premiere = null;

  final DateTime? premiere;
  final int? premiereOffsetDays;
  final int episodes;

  /// Days between episodes (0 = full-season drop, binge style).
  final int intervalDays;
  final List<String> titles;

  DateTime premiereDate(DateTime today) =>
      premiere ?? today.add(Duration(days: premiereOffsetDays!));
}

class MockShowSeed {
  const MockShowSeed({
    required this.id,
    required this.name,
    required this.overview,
    required this.genreIds,
    required this.status,
    required this.networks,
    required this.runtime,
    required this.rating,
    required this.voteCount,
    required this.popularity,
    required this.seasons,
    required this.cast,
    this.posterPath,
    this.backdropPath,
    this.originalName,
    this.originalLanguage = 'en',
    this.originCountries = const ['US'],
    this.tagline = '',
    this.aliases = const [],
  });

  final int id;
  final String name;
  final String? originalName;
  final String overview;
  final String tagline;
  final List<int> genreIds;
  final ShowStatus status;
  final List<String> networks;
  final int runtime;
  final double rating;
  final int voteCount;
  final double popularity;
  final List<MockSeasonSeed> seasons;
  final List<CastMember> cast;
  final String? posterPath;
  final String? backdropPath;
  final String originalLanguage;
  final List<String> originCountries;
  final List<String> aliases;

  String? get posterUrl => posterPath != null
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : null;

  String? get backdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : null;

  List<Genre> get genres =>
      genreIds.map(Genre.byId).whereType<Genre>().toList();
}

CastMember _c(int id, String name, String character) =>
    CastMember(id: id, name: name, character: character);

/// Curated demo catalogue (TV shows & anime only). IDs mirror TMDB ids so
/// tracking data stays meaningful once a real API key is configured.
final List<MockShowSeed> mockCatalog = [
  MockShowSeed(
    id: 1396,
    name: 'Breaking Bad',
    tagline: 'Remember my name.',
    posterPath: '/ggFHVNu6YYI5L9pCfOacjizRGt.jpg',
    backdropPath: '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg',
    overview:
        'Walter White, um professor de química do secundário com um cancro '
        'terminal, junta-se a um antigo aluno para produzir e vender '
        'metanfetamina e garantir o futuro financeiro da família.',
    genreIds: [18, 80],
    status: ShowStatus.ended,
    networks: ['AMC'],
    runtime: 47,
    rating: 8.9,
    voteCount: 15800,
    popularity: 410,
    seasons: [
      MockSeasonSeed.at(DateTime(2008, 1, 20), episodes: 7, titles: [
        'Pilot',
        "Cat's in the Bag...",
        "...And the Bag's in the River",
        'Cancer Man',
        'Gray Matter',
        "Crazy Handful of Nothin'",
        'A No-Rough-Stuff-Type Deal',
      ]),
      MockSeasonSeed.at(DateTime(2009, 3, 8), episodes: 13),
      MockSeasonSeed.at(DateTime(2010, 3, 21), episodes: 13),
      MockSeasonSeed.at(DateTime(2011, 7, 17), episodes: 13),
      MockSeasonSeed.at(DateTime(2012, 7, 15), episodes: 16),
    ],
    cast: [
      _c(17419, 'Bryan Cranston', 'Walter White'),
      _c(84497, 'Aaron Paul', 'Jesse Pinkman'),
      _c(134531, 'Anna Gunn', 'Skyler White'),
      _c(14329, 'Dean Norris', 'Hank Schrader'),
      _c(59410, 'Bob Odenkirk', 'Saul Goodman'),
      _c(209674, 'RJ Mitte', 'Walter White Jr.'),
    ],
  ),
  MockShowSeed(
    id: 95396,
    name: 'Severance',
    posterPath: '/jH29N46bKk6mR289Q16t17kZ7XF.jpg',
    backdropPath: '/9xxLWtn8UjNalT2fN64qXm2eZ2U.jpg',
    overview:
        'Mark lidera uma equipa na Lumon Industries, cujos funcionários '
        'foram submetidos a um procedimento que separa cirurgicamente as '
        'memórias do trabalho das da vida pessoal.',
    genreIds: [18, 9648, 10765],
    status: ShowStatus.returning,
    networks: ['Apple TV+'],
    runtime: 55,
    rating: 8.4,
    voteCount: 2900,
    popularity: 380,
    seasons: [
      MockSeasonSeed.at(DateTime(2022, 2, 18), episodes: 9, titles: [
        'Good News About Hell',
        'Half Loop',
        'In Perpetuity',
        'The You You Are',
        'The Grim Barbarity of Optics and Design',
        'Hide and Seek',
        'Defiant Jazz',
        "What's for Dinner?",
        'The We We Are',
      ]),
      MockSeasonSeed.at(DateTime(2025, 1, 17), episodes: 10),
      MockSeasonSeed.relative(24, episodes: 10),
    ],
    cast: [
      _c(1, 'Adam Scott', 'Mark Scout'),
      _c(2, 'Britt Lower', 'Helly R.'),
      _c(3, 'Zach Cherry', 'Dylan G.'),
      _c(4, 'John Turturro', 'Irving B.'),
      _c(5, 'Patricia Arquette', 'Harmony Cobel'),
      _c(6, 'Tramell Tillman', 'Seth Milchick'),
    ],
  ),
  MockShowSeed(
    id: 100088,
    name: 'The Last of Us',
    posterPath: '/uKvVjK1ohzi2eH39Vatg0vUa411.jpg',
    backdropPath: '/uDgy6hyPd82kOHh6I95FLtLnj6p.jpg',
    overview:
        'Vinte anos após o colapso da civilização, Joel, um sobrevivente '
        'endurecido, é contratado para tirar Ellie, uma rapariga de 14 anos, '
        'de uma zona de quarentena opressiva.',
    genreIds: [18, 10759, 10765],
    status: ShowStatus.returning,
    networks: ['HBO'],
    runtime: 55,
    rating: 8.6,
    voteCount: 5600,
    popularity: 520,
    seasons: [
      MockSeasonSeed.at(DateTime(2023, 1, 15), episodes: 9, titles: [
        "When You're Lost in the Darkness",
        'Infected',
        'Long, Long Time',
        'Please Hold to My Hand',
        'Endure and Survive',
        'Kin',
        'Left Behind',
        'When We Are in Need',
        'Look for the Light',
      ]),
      MockSeasonSeed.at(DateTime(2025, 4, 13), episodes: 7),
      MockSeasonSeed.relative(-17, episodes: 8),
    ],
    cast: [
      _c(7, 'Pedro Pascal', 'Joel Miller'),
      _c(8, 'Bella Ramsey', 'Ellie Williams'),
      _c(9, 'Gabriel Luna', 'Tommy Miller'),
      _c(10, 'Isabela Merced', 'Dina'),
    ],
  ),
  MockShowSeed(
    id: 209867,
    name: 'Frieren: Beyond Journey\'s End',
    originalName: 'Sousou no Frieren',
    aliases: ['Sousou no Frieren', '葬送のフリーレン'],
    posterPath: '/dqZENchTd7lp5zht7BdlqM7RBhD.jpg',
    backdropPath: '/2rmK7mnchw9Xr3XdiTFSxTTvYQI.jpg',
    overview:
        'Depois de derrotar o Rei Demónio, a maga elfa Frieren parte numa '
        'nova viagem para compreender os humanos e o tempo que passou com '
        'os seus antigos companheiros.',
    genreIds: [16, 10759, 10765, 18],
    status: ShowStatus.returning,
    networks: ['Nippon TV'],
    runtime: 24,
    rating: 8.8,
    voteCount: 900,
    popularity: 300,
    originalLanguage: 'ja',
    originCountries: ['JP'],
    seasons: [
      MockSeasonSeed.at(DateTime(2023, 9, 29), episodes: 28),
      MockSeasonSeed.relative(-35, episodes: 12),
    ],
    cast: [
      _c(11, 'Atsumi Tanezaki', 'Frieren (voz)'),
      _c(12, 'Kana Ichinose', 'Fern (voz)'),
      _c(13, 'Chiaki Kobayashi', 'Stark (voz)'),
      _c(14, 'Nobuhiko Okamoto', 'Himmel (voz)'),
    ],
  ),
  MockShowSeed(
    id: 126308,
    name: 'Shōgun',
    posterPath: '/7O4iVfOMQmdCSPxSwiqx5Yq46Q9.jpg',
    backdropPath: '/5kkw5RT1OjMm9VO2um9829lB2.jpg',
    overview:
        'No Japão de 1600, o senhor Yoshii Toranaga luta pela sobrevivência '
        'enquanto os seus inimigos no Conselho de Regentes se unem contra '
        'ele — e um misterioso navio europeu dá à costa.',
    genreIds: [18, 10768],
    status: ShowStatus.returning,
    networks: ['FX'],
    runtime: 60,
    rating: 8.5,
    voteCount: 1300,
    popularity: 260,
    aliases: ['Shogun'],
    seasons: [
      MockSeasonSeed.at(DateTime(2024, 2, 27), episodes: 10, titles: [
        'Anjin',
        'Servants of Two Masters',
        'Tomorrow Is Tomorrow',
        'The Eightfold Fence',
        'Broken to the Fist',
        'Ladies of the Willow World',
        'A Stick of Time',
        'The Abyss of Life',
        'Crimson Sky',
        'A Dream of a Dream',
      ]),
    ],
    cast: [
      _c(15, 'Hiroyuki Sanada', 'Yoshii Toranaga'),
      _c(16, 'Cosmo Jarvis', 'John Blackthorne'),
      _c(17, 'Anna Sawai', 'Toda Mariko'),
      _c(18, 'Tadanobu Asano', 'Kashigi Yabushige'),
    ],
  ),
  MockShowSeed(
    id: 136315,
    name: 'The Bear',
    posterPath: '/r3A7evKLNp7LM8A80eWz6v2bI7b.jpg',
    backdropPath: '/3r1hX66sE554J9W1h23z4B17L6.jpg',
    overview:
        'Um jovem chef de alta cozinha regressa a Chicago para gerir a '
        'sandwicharia da família após uma tragédia, enfrentando uma equipa '
        'caótica e o seu próprio passado.',
    genreIds: [18, 35],
    status: ShowStatus.returning,
    networks: ['FX'],
    runtime: 32,
    rating: 8.2,
    voteCount: 1100,
    popularity: 190,
    seasons: [
      MockSeasonSeed.at(DateTime(2022, 6, 23), episodes: 8, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2023, 6, 22), episodes: 10, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2024, 6, 26), episodes: 10, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2025, 6, 25), episodes: 10, intervalDays: 0),
    ],
    cast: [
      _c(19, 'Jeremy Allen White', 'Carmen "Carmy" Berzatto'),
      _c(20, 'Ebon Moss-Bachrach', 'Richie Jerimovich'),
      _c(21, 'Ayo Edebiri', 'Sydney Adamu'),
      _c(22, 'Abby Elliott', 'Natalie Berzatto'),
    ],
  ),
  MockShowSeed(
    id: 94605,
    name: 'Arcane',
    posterPath: '/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg',
    backdropPath: '/2OMB0ynKlyIen9NxLQ0RdtP9whP.jpg',
    overview:
        'Entre a utópica Piltover e a opressiva cidade subterrânea de Zaun, '
        'as irmãs Vi e Jinx acabam em lados opostos de uma guerra de '
        'tecnologias mágicas e convicções inconciliáveis.',
    genreIds: [16, 10765, 10759, 18],
    status: ShowStatus.ended,
    networks: ['Netflix'],
    runtime: 40,
    rating: 8.7,
    voteCount: 4700,
    popularity: 240,
    seasons: [
      MockSeasonSeed.at(DateTime(2021, 11, 6), episodes: 9, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2024, 11, 9), episodes: 9, intervalDays: 0),
    ],
    cast: [
      _c(23, 'Hailee Steinfeld', 'Vi (voz)'),
      _c(24, 'Ella Purnell', 'Jinx (voz)'),
      _c(25, 'Kevin Alejandro', 'Jayce (voz)'),
      _c(26, 'Katie Leung', 'Caitlyn (voz)'),
    ],
  ),
  MockShowSeed(
    id: 95479,
    name: 'Jujutsu Kaisen',
    originalName: '呪術廻戦',
    aliases: ['呪術廻戦', 'JJK'],
    posterPath: '/fHpKWvE3aW4b3p7L7iC8uE23J1d.jpg',
    backdropPath: '/gmECkdGbhAuZPJyiU7Z6hv0621U.jpg',
    overview:
        'Yuji Itadori, um estudante com força sobre-humana, engole um dedo '
        'amaldiçoado para salvar os amigos e torna-se hospedeiro de Sukuna, '
        'o mais poderoso dos espíritos amaldiçoados.',
    genreIds: [16, 10759, 10765],
    status: ShowStatus.returning,
    networks: ['MBS'],
    runtime: 24,
    rating: 8.6,
    voteCount: 3600,
    popularity: 330,
    originalLanguage: 'ja',
    originCountries: ['JP'],
    seasons: [
      MockSeasonSeed.at(DateTime(2020, 10, 3), episodes: 24),
      MockSeasonSeed.at(DateTime(2023, 7, 6), episodes: 23),
      MockSeasonSeed.relative(-28, episodes: 12),
    ],
    cast: [
      _c(27, 'Junya Enoki', 'Yuji Itadori (voz)'),
      _c(28, 'Yuma Uchida', 'Megumi Fushiguro (voz)'),
      _c(29, 'Asami Seto', 'Nobara Kugisaki (voz)'),
      _c(30, 'Yuichi Nakamura', 'Satoru Gojo (voz)'),
    ],
  ),
  MockShowSeed(
    id: 76479,
    name: 'The Boys',
    posterPath: '/2zmTngn1tYC1AvfnflRJ1PO4qhG.jpg',
    backdropPath: '/n6bUvigpRFqSwmPp1m2YADdbRBc.jpg',
    overview:
        'Num mundo onde os super-heróis são celebridades corruptas geridas '
        'por uma megacorporação, um grupo de vigilantes decide expor a '
        'verdade sobre os "Sete".',
    genreIds: [10765, 10759, 35],
    status: ShowStatus.returning,
    networks: ['Prime Video'],
    runtime: 60,
    rating: 8.4,
    voteCount: 10200,
    popularity: 450,
    seasons: [
      MockSeasonSeed.at(DateTime(2019, 7, 26), episodes: 8, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2020, 9, 4), episodes: 8),
      MockSeasonSeed.at(DateTime(2022, 6, 3), episodes: 8),
      MockSeasonSeed.at(DateTime(2024, 6, 13), episodes: 8),
      MockSeasonSeed.relative(-42, episodes: 8),
    ],
    cast: [
      _c(31, 'Karl Urban', 'Billy Butcher'),
      _c(32, 'Jack Quaid', 'Hughie Campbell'),
      _c(33, 'Antony Starr', 'Homelander'),
      _c(34, 'Erin Moriarty', 'Annie January / Starlight'),
    ],
  ),
  MockShowSeed(
    id: 94997,
    name: 'House of the Dragon',
    posterPath: '/7QMsOTMUswlwxJP0rTTZfmz2tX2.jpg',
    backdropPath: '/etj5CuMuam3U9KuV405cqWymVOq.jpg',
    overview:
        'Duzentos anos antes de Game of Thrones, a Casa Targaryen está no '
        'auge do seu poder — até que uma disputa pela sucessão ameaça '
        'mergulhar Westeros numa guerra civil.',
    genreIds: [10765, 18, 10759],
    status: ShowStatus.returning,
    networks: ['HBO'],
    runtime: 62,
    rating: 8.3,
    voteCount: 4900,
    popularity: 400,
    seasons: [
      MockSeasonSeed.at(DateTime(2022, 8, 21), episodes: 10),
      MockSeasonSeed.at(DateTime(2024, 6, 16), episodes: 8),
      MockSeasonSeed.relative(52, episodes: 8),
    ],
    cast: [
      _c(35, 'Matt Smith', 'Daemon Targaryen'),
      _c(36, "Emma D'Arcy", 'Rhaenyra Targaryen'),
      _c(37, 'Olivia Cooke', 'Alicent Hightower'),
      _c(38, 'Paddy Considine', 'Viserys I Targaryen'),
    ],
  ),
  MockShowSeed(
    id: 95480,
    name: 'Slow Horses',
    originCountries: ['GB'],
    posterPath: '/6b9u8kQpP8Wf6yG26Q3y9E8fF1T.jpg',
    backdropPath: '/r0A5r6Q075zX5F8H4b1cT6sD7l0.jpg',
    overview:
        'Um grupo de agentes do MI5 caídos em desgraça, liderados pelo '
        'brilhante mas insuportável Jackson Lamb, é relegado para a '
        '"Slough House" — mas não desiste de provar o seu valor.',
    genreIds: [80, 18, 35],
    status: ShowStatus.returning,
    networks: ['Apple TV+'],
    runtime: 45,
    rating: 8.1,
    voteCount: 700,
    popularity: 150,
    seasons: [
      MockSeasonSeed.at(DateTime(2022, 4, 1), episodes: 6),
      MockSeasonSeed.at(DateTime(2022, 12, 2), episodes: 6),
      MockSeasonSeed.at(DateTime(2023, 11, 29), episodes: 6),
      MockSeasonSeed.at(DateTime(2024, 9, 4), episodes: 6),
      MockSeasonSeed.relative(-10, episodes: 6),
    ],
    cast: [
      _c(39, 'Gary Oldman', 'Jackson Lamb'),
      _c(40, 'Jack Lowden', 'River Cartwright'),
      _c(41, 'Kristin Scott Thomas', 'Diana Taverner'),
      _c(42, 'Saskia Reeves', 'Catherine Standish'),
    ],
  ),
  MockShowSeed(
    id: 66732,
    name: 'Stranger Things',
    posterPath: '/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
    backdropPath: '/56v2KjBlU4XaOv9rVYEQypROD7P.jpg',
    overview:
        'Quando um rapaz desaparece em Hawkins, Indiana, os amigos, a '
        'família e a polícia local enfrentam forças sobrenaturais e '
        'experiências governamentais secretas.',
    genreIds: [18, 10765, 9648],
    status: ShowStatus.ended,
    networks: ['Netflix'],
    runtime: 60,
    rating: 8.6,
    voteCount: 18500,
    popularity: 480,
    seasons: [
      MockSeasonSeed.at(DateTime(2016, 7, 15), episodes: 8, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2017, 10, 27), episodes: 9, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2019, 7, 4), episodes: 8, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2022, 5, 27), episodes: 9, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2025, 11, 26), episodes: 8, intervalDays: 0),
    ],
    cast: [
      _c(43, 'Millie Bobby Brown', 'Eleven'),
      _c(44, 'Finn Wolfhard', 'Mike Wheeler'),
      _c(45, 'Winona Ryder', 'Joyce Byers'),
      _c(46, 'David Harbour', 'Jim Hopper'),
    ],
  ),
  MockShowSeed(
    id: 83867,
    name: 'Andor',
    posterPath: '/59SVNwL2O74e204k1A4bT5A3vN2.jpg',
    backdropPath: '/ajztm40qDP5rTwDrqjM1a9807.jpg',
    overview:
        'Nos anos que antecedem Rogue One, o ladrão Cassian Andor descobre '
        'a sua causa enquanto a rebelião contra o Império começa a ganhar '
        'forma pela galáxia.',
    genreIds: [10765, 10768, 18, 10759],
    status: ShowStatus.ended,
    networks: ['Disney+'],
    runtime: 45,
    rating: 8.3,
    voteCount: 1600,
    popularity: 170,
    seasons: [
      MockSeasonSeed.at(DateTime(2022, 9, 21), episodes: 12),
      MockSeasonSeed.at(DateTime(2025, 4, 22), episodes: 12),
    ],
    cast: [
      _c(47, 'Diego Luna', 'Cassian Andor'),
      _c(48, 'Stellan Skarsgård', 'Luthen Rael'),
      _c(49, "Genevieve O'Reilly", 'Mon Mothma'),
      _c(50, 'Denise Gough', 'Dedra Meero'),
    ],
  ),
  MockShowSeed(
    id: 76331,
    name: 'Succession',
    posterPath: '/7duLrh2GqN2LffO9B2z26Pj5zZt.jpg',
    backdropPath: '/wPcuu7e02zU3e0q3k1m4v6x8b1.jpg',
    overview:
        'A família Roy controla um dos maiores conglomerados de media do '
        'mundo — e os quatro filhos de Logan Roy disputam implacavelmente '
        'a sucessão do patriarca.',
    genreIds: [18, 35],
    status: ShowStatus.ended,
    networks: ['HBO'],
    runtime: 62,
    rating: 8.4,
    voteCount: 2400,
    popularity: 120,
    seasons: [
      MockSeasonSeed.at(DateTime(2018, 6, 3), episodes: 10),
      MockSeasonSeed.at(DateTime(2019, 8, 11), episodes: 10),
      MockSeasonSeed.at(DateTime(2021, 10, 17), episodes: 9),
      MockSeasonSeed.at(DateTime(2023, 3, 26), episodes: 10),
    ],
    cast: [
      _c(51, 'Brian Cox', 'Logan Roy'),
      _c(52, 'Jeremy Strong', 'Kendall Roy'),
      _c(53, 'Sarah Snook', 'Siobhan "Shiv" Roy'),
      _c(54, 'Kieran Culkin', 'Roman Roy'),
    ],
  ),
  MockShowSeed(
    id: 70523,
    name: 'Dark',
    originalLanguage: 'de',
    originCountries: ['DE'],
    posterPath: '/apbrkOxJw8cmxi003W3j7T8B2A6.jpg',
    backdropPath: '/3lBDg3i6nn5R2NK74LzZ7wD9dYJ.jpg',
    overview:
        'O desaparecimento de duas crianças numa pequena cidade alemã '
        'revela as relações fraturadas, a vida dupla e o passado sombrio de '
        'quatro famílias ligadas através do tempo.',
    genreIds: [80, 18, 10765, 9648],
    status: ShowStatus.ended,
    networks: ['Netflix'],
    runtime: 55,
    rating: 8.4,
    voteCount: 6800,
    popularity: 140,
    seasons: [
      MockSeasonSeed.at(DateTime(2017, 12, 1), episodes: 10, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2019, 6, 21), episodes: 8, intervalDays: 0),
      MockSeasonSeed.at(DateTime(2020, 6, 27), episodes: 8, intervalDays: 0),
    ],
    cast: [
      _c(55, 'Louis Hofmann', 'Jonas Kahnwald'),
      _c(56, 'Lisa Vicari', 'Martha Nielsen'),
      _c(57, 'Oliver Masucci', 'Ulrich Nielsen'),
      _c(58, 'Karoline Eichhorn', 'Charlotte Doppler'),
    ],
  ),
  MockShowSeed(
    id: 114410,
    name: 'Chainsaw Man',
    originalName: 'チェンソーマン',
    aliases: ['チェンソーマン'],
    originalLanguage: 'ja',
    originCountries: ['JP'],
    posterPath: '/npdB6eFz4qt9CdEiEgXOsvQg6la.jpg',
    backdropPath: '/k2Lcq8mN29FkE9FvA9l840B0r8w.jpg',
    overview:
        'Denji, um jovem afogado em dívidas, funde-se com o seu demónio de '
        'estimação Pochita e torna-se o Chainsaw Man, sendo recrutado por '
        'uma organização governamental de caçadores de demónios.',
    genreIds: [16, 10759, 10765],
    status: ShowStatus.returning,
    networks: ['TV Tokyo'],
    runtime: 24,
    rating: 8.5,
    voteCount: 1500,
    popularity: 210,
    seasons: [
      MockSeasonSeed.at(DateTime(2022, 10, 12), episodes: 12),
    ],
    cast: [
      _c(59, 'Kikunosuke Toya', 'Denji (voz)'),
      _c(60, 'Tomori Kusunoki', 'Makima (voz)'),
      _c(61, 'Fairouz Ai', 'Power (voz)'),
    ],
  ),
  MockShowSeed(
    id: 97546,
    name: 'Ted Lasso',
    posterPath: '/5bFK5d3mVTAvBC0bVzpOxN8gzNs.jpg',
    backdropPath: '/4N21P34X4lU1s23Y4c5D6e7F8g.jpg',
    overview:
        'Um treinador de futebol americano universitário é contratado para '
        'treinar um clube da Premier League inglesa, apesar de não saber '
        'nada sobre o desporto.',
    genreIds: [35, 18],
    status: ShowStatus.returning,
    networks: ['Apple TV+'],
    runtime: 35,
    rating: 8.4,
    voteCount: 1300,
    popularity: 160,
    seasons: [
      MockSeasonSeed.at(DateTime(2020, 8, 14), episodes: 10),
      MockSeasonSeed.at(DateTime(2021, 7, 23), episodes: 12),
      MockSeasonSeed.at(DateTime(2023, 3, 15), episodes: 12),
      MockSeasonSeed.relative(-3, episodes: 10),
    ],
    cast: [
      _c(62, 'Jason Sudeikis', 'Ted Lasso'),
      _c(63, 'Hannah Waddingham', 'Rebecca Welton'),
      _c(64, 'Brett Goldstein', 'Roy Kent'),
      _c(65, 'Juno Temple', 'Keeley Jones'),
    ],
  ),
  MockShowSeed(
    id: 120089,
    name: 'SPY x FAMILY',
    originalName: 'SPY×FAMILY',
    aliases: ['Spy Family'],
    originalLanguage: 'ja',
    originCountries: ['JP'],
    posterPath: '/wJ5h1lS6d1qR124A1Y27mHkQ0q.jpg',
    backdropPath: '/8sNi5RkxWpmfT4tH7hO5n09l8Wq.jpg',
    overview:
        'O espião Twilight tem de formar uma família falsa para cumprir uma '
        'missão — sem saber que a filha adotiva lê mentes e que a esposa é '
        'uma assassina profissional.',
    genreIds: [16, 35, 10759, 10751],
    status: ShowStatus.returning,
    networks: ['TV Tokyo'],
    runtime: 24,
    rating: 8.5,
    voteCount: 1800,
    popularity: 230,
    seasons: [
      MockSeasonSeed.at(DateTime(2022, 4, 9), episodes: 25),
      MockSeasonSeed.at(DateTime(2023, 10, 7), episodes: 12),
      MockSeasonSeed.relative(-1, episodes: 13),
    ],
    cast: [
      _c(66, 'Takuya Eguchi', 'Loid Forger (voz)'),
      _c(67, 'Atsumi Tanezaki', 'Anya Forger (voz)'),
      _c(68, 'Saori Hayami', 'Yor Forger (voz)'),
    ],
  ),
];
