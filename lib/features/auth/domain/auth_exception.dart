/// User-facing authentication failure with a Portuguese message.
class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  /// Maps Firebase Auth error codes to friendly Portuguese messages.
  factory AuthException.fromCode(String code, [String? fallback]) {
    final message = switch (code) {
      'invalid-email' => 'O endereço de email não é válido.',
      'user-disabled' => 'Esta conta foi desativada.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        'Email ou palavra-passe incorretos.',
      'email-already-in-use' => 'Já existe uma conta com este email.',
      'weak-password' => 'A palavra-passe é demasiado fraca (mínimo 6 caracteres).',
      'too-many-requests' =>
        'Demasiadas tentativas. Aguarda uns minutos e tenta novamente.',
      'network-request-failed' =>
        'Sem ligação à internet. Verifica a tua rede e tenta novamente.',
      'operation-not-allowed' =>
        'Este método de autenticação não está ativo no projeto Firebase.',
      'account-exists-with-different-credential' =>
        'Este email já está associado a outro método de início de sessão.',
      'popup-closed-by-user' || 'cancelled-popup-request' =>
        'Início de sessão cancelado.',
      _ => fallback ?? 'Ocorreu um erro de autenticação ($code).',
    };
    return AuthException(message, code: code);
  }

  /// Thrown when Firebase is not configured for this build.
  static const unavailable = AuthException(
    'A autenticação ainda não está configurada nesta versão da app '
    '(Firebase em falta). Podes continuar como convidado.',
    code: 'auth-unavailable',
  );

  final String message;
  final String? code;

  @override
  String toString() => message;
}
