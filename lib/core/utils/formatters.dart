import 'package:intl/intl.dart';

/// Presentation helpers (pt-PT).
abstract final class Formatters {
  static final DateFormat _fullDate = DateFormat("d 'de' MMMM 'de' y", 'pt_PT');
  static final DateFormat _shortDate = DateFormat('d MMM y', 'pt_PT');
  static final DateFormat _dayMonth = DateFormat('d MMM', 'pt_PT');
  static final DateFormat _weekdayDate =
      DateFormat("EEEE, d 'de' MMMM", 'pt_PT');

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String fullDate(DateTime? d) => d == null ? '—' : _fullDate.format(d);
  static String shortDate(DateTime? d) =>
      d == null ? 'Data por anunciar' : _shortDate.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);

  /// "Hoje", "Amanhã" or e.g. "Sexta-feira, 16 de outubro".
  static String relativeDayHeader(DateTime day, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final diff = dateOnly(day).difference(today).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    if (diff == -1) return 'Ontem';
    return _capitalize(_weekdayDate.format(day));
  }

  /// "hoje", "amanhã", "em 5 dias".
  static String countdown(DateTime day, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final diff = dateOnly(day).difference(today).inDays;
    if (diff <= 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    return 'Em $diff dias';
  }

  /// Total watch time, e.g. "3d 4h" or "45 min".
  static String watchTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final days = minutes ~/ 1440;
    final hours = (minutes % 1440) ~/ 60;
    if (days == 0) return '${hours}h ${minutes % 60}min';
    return '${days}d ${hours}h';
  }

  static String runtime(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  static String rating(double value) => value.toStringAsFixed(1);

  static String percent(double ratio) => '${(ratio * 100).round()}%';

  static String compactNumber(num value) =>
      NumberFormat.compact(locale: 'pt_PT').format(value);

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Lower-cases and strips common diacritics so "shogun" matches "Shōgun".
String normalizeForSearch(String input) {
  const from = 'àáâãäåāçèéêëēìíîïīñòóôõöōùúûüūýÿ';
  const to = 'aaaaaaaceeeeeiiiiinoooooouuuuuyy';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString().trim();
}
