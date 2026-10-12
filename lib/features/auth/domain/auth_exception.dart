/// User-facing authentication failure with an English message.
class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  /// Maps Firebase Auth error codes to friendly English messages.
  factory AuthException.fromCode(String code, [String? fallback]) {
    final message = switch (code) {
      'invalid-email' => 'The email address is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists with this email.',
      'weak-password' => 'The password is too weak (minimum 6 characters).',
      'too-many-requests' =>
        'Too many attempts. Please wait a few minutes and try again.',
      'network-request-failed' =>
        'No internet connection. Please check your network and try again.',
      'operation-not-allowed' =>
        'This authentication method is not enabled.',
      'account-exists-with-different-credential' =>
        'This email is already associated with another sign-in method.',
      'popup-closed-by-user' || 'cancelled-popup-request' =>
        'Sign in was cancelled.',
      _ => fallback ?? 'Authentication error occurred ($code).',
    };
    return AuthException(message, code: code);
  }

  /// Thrown when Firebase is not configured for this build.
  static const unavailable = AuthException(
    'Authentication is not configured in this version of the app '
    '(Firebase missing).',
    code: 'auth-unavailable',
  );

  final String message;
  final String? code;

  @override
  String toString() => message;
}
