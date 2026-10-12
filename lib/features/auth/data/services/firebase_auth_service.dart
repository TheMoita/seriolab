import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/auth_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/services/auth_service.dart';

/// Firebase implementation of [AuthService] backed by `firebase_auth`
/// and `google_sign_in`.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    required this.auth,
    GoogleSignIn? googleSignIn,
    this.serverClientId = defaultServerClientId,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Web Client ID from Firebase / Google Cloud Console to ensure idToken is returned on Android.
  static const String defaultServerClientId =
      '686239497156-tp2m4tqbubp9ic3lq74parcok577mra2.apps.googleusercontent.com';

  final FirebaseAuth auth;
  final GoogleSignIn _googleSignIn;
  final String? serverClientId;

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser {
    final user = auth.currentUser;
    return user == null ? null : _mapFirebaseUser(user);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return auth.authStateChanges().map((u) => u == null ? null : _mapFirebaseUser(u));
  }

  @override
  Future<AppUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Não foi possível obter a conta autenticada.');
      }
      return _mapFirebaseUser(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code, e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Erro ao iniciar sessão: $e');
    }
  }

  @override
  Future<AppUser> registerWithEmailAndPassword(
    String email,
    String password,
    String username,
  ) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Falha ao criar utilizador no Firebase.');
      }

      final cleanUsername = AppUser.sanitizeUsername(username);
      try {
        await user.updateDisplayName(cleanUsername);
        await user.reload();
      } catch (_) {}

      final updated = auth.currentUser ?? user;
      return _mapFirebaseUser(updated);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code, e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Erro ao registar conta: $e');
    }
  }

  @override
  Future<AppUser?> signInWithGoogle({BuildContext? context}) async {
    void showFeedback(String message) {
      debugPrint('Google Sign-In Debug: $message');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    void showErrorDialog(Object error, StackTrace stack) {
      debugPrint('Erro no Login: $error\n\n$stack');
      if (context != null && context.mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Erro no Login'),
            content: SingleChildScrollView(
              child: Text('$error\n\n$stack'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
    }

    try {
      // 1. Antes de chamar signIn():
      showFeedback('A abrir seletor Google...');
      debugPrint('FirebaseAuthService: A inicializar Google Sign-In...');
      await _googleSignIn.initialize(
        serverClientId: serverClientId,
      );

      // 2. Imediatamente após GoogleSignIn:
      GoogleSignInAccount account;
      try {
        account = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e, stack) {
        debugPrint(
          'Erro detalhado no Google Sign-In (GoogleSignInException): ${e.code.name} - ${e.description}',
        );
        if (e.code == GoogleSignInExceptionCode.canceled) {
          showFeedback('Google devolveu NULL (Cancelado ou SHA-1 inválida).');
          return null;
        }
        showErrorDialog(e, stack);
        throw AuthException(
          'Falha no Google Sign-In: ${e.description ?? e.code.name}',
          code: e.code.name,
        );
      } catch (e, stack) {
        if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
          showFeedback('Google devolveu NULL (Cancelado ou SHA-1 inválida).');
          return null;
        }
        showErrorDialog(e, stack);
        rethrow;
      }

      showFeedback('Conta selecionada: ${account.email}');

      // 3. Após obter os tokens de autenticação:
      final authTokens = account.authentication;
      final idToken = authTokens.idToken;

      String? accessToken;
      try {
        final clientAuth = await account.authorizationClient.authorizationForScopes([
          'email',
          'profile',
        ]);
        accessToken = clientAuth?.accessToken;
      } catch (scopeError) {
        debugPrint('FirebaseAuthService: Authorization scopes note: $scopeError');
      }

      showFeedback('Tokens obtidos: idToken=${idToken != null}');

      if (idToken == null && accessToken == null) {
        throw const AuthException(
          'Não foi possível obter tokens de autenticação do Google.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException(
          'Utilizador não retornado pelo Firebase após autenticação.',
        );
      }

      debugPrint(
        'FirebaseAuthService: Google Sign-In concluído com sucesso para: ${user.email ?? user.uid}',
      );
      return _mapFirebaseUser(user);
    } on GoogleSignInException catch (e, stack) {
      debugPrint(
        'Erro detalhado no Google Sign-In (GoogleSignInException): ${e.code.name} - ${e.description}',
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        showFeedback('Google devolveu NULL (Cancelado ou SHA-1 inválida).');
        return null;
      }
      showErrorDialog(e, stack);
      throw AuthException(
        'Falha no Google Sign-In: ${e.description ?? e.code.name}',
        code: e.code.name,
      );
    } on FirebaseAuthException catch (e, stack) {
      debugPrint(
        'Erro detalhado no Google Sign-In (FirebaseAuthException): [${e.code}] ${e.message}',
      );
      showErrorDialog(e, stack);
      throw AuthException.fromCode(e.code, e.message);
    } catch (e, stack) {
      debugPrint('Erro detalhado no Google Sign-In: $e');
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
        showFeedback('Google devolveu NULL (Cancelado ou SHA-1 inválida).');
        return null;
      }
      showErrorDialog(e, stack);
      if (e is AuthException) rethrow;
      throw AuthException('Falha ao autenticar com o Google: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await auth.signOut();
  }

  AppUser _mapFirebaseUser(User user) {
    final isGoogle = user.providerData.any(
      (p) => p.providerId == 'google.com' || p.providerId == GoogleAuthProvider.PROVIDER_ID,
    );
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      provider: isGoogle ? AuthProviderKind.google : AuthProviderKind.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
