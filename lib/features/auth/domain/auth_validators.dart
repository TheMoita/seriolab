/// Form validators shared by the login and registration screens.
///
/// Each returns `null` when valid, otherwise a Portuguese error message.
abstract final class AuthValidators {
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  static const int minPasswordLength = 6;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Introduz o teu email.';
    if (!_emailRegex.hasMatch(v)) return 'Introduz um email válido.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Introduz a palavra-passe.';
    if (v.length < minPasswordLength) {
      return 'A palavra-passe deve ter pelo menos $minPasswordLength caracteres.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirma a palavra-passe.';
    if (value != original) return 'As palavras-passe não coincidem.';
    return null;
  }

  /// Accepts an optional leading `@`.
  static String? username(String? value) {
    final v = normalizeUsername(value ?? '');
    if (v.isEmpty) return 'Escolhe um nome de utilizador.';
    if (!_usernameRegex.hasMatch(v)) {
      return 'Usa 3 a 20 caracteres: letras, números, "_" ou ".".';
    }
    return null;
  }

  static String normalizeUsername(String value) {
    final v = value.trim();
    return v.startsWith('@') ? v.substring(1) : v;
  }
}
