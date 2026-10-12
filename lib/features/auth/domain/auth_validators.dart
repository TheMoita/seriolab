/// Form validators shared by the login and registration screens.
///
/// Each returns `null` when valid, otherwise an English error message.
abstract final class AuthValidators {
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  static const int minPasswordLength = 6;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email.';
    if (!_emailRegex.hasMatch(v)) return 'Please enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter your password.';
    if (v.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  /// Accepts an optional leading `@`.
  static String? username(String? value) {
    final v = normalizeUsername(value ?? '');
    if (v.isEmpty) return 'Please choose a username.';
    if (!_usernameRegex.hasMatch(v)) {
      return 'Use 3 to 20 characters: letters, numbers, "_" or ".';
    }
    return null;
  }

  static String normalizeUsername(String value) {
    final v = value.trim();
    return v.startsWith('@') ? v.substring(1) : v;
  }
}
