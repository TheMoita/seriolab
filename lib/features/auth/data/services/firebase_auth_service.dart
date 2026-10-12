import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/auth_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/services/auth_service.dart';

/// Firebase implementation of [AuthService] backed by `firebase_auth`.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    required this.auth,
  });

  final FirebaseAuth auth;

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
        throw const AuthException('Unable to retrieve authenticated account.');
      }
      return _mapFirebaseUser(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code, e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Error signing in: $e');
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
        throw const AuthException('Failed to create user in Firebase.');
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
      throw AuthException('Error registering account: $e');
    }
  }

  @override
  Future<void> signOut() async {
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
