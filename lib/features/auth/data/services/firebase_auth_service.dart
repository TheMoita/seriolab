import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth auth;
  final GoogleSignIn _googleSignIn;

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
  Future<AppUser?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final account = await _googleSignIn.authenticate();

      final authTokens = account.authentication;
      final idToken = authTokens.idToken;

      String? accessToken;
      try {
        final clientAuth = await account.authorizationClient.authorizationForScopes([
          'email',
          'profile',
        ]);
        accessToken = clientAuth?.accessToken;
      } catch (_) {}

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return null;

      return _mapFirebaseUser(user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw AuthException(
        'Falha no Google Sign-In: ${e.description ?? e.code.name}',
        code: e.code.name,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code, e.message);
    } catch (e) {
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
        return null;
      }
      if (e is AuthException) rethrow;
      throw AuthException('Erro ao autenticar com Google: $e');
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
