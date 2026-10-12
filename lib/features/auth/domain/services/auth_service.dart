import 'package:flutter/widgets.dart';

import '../entities/app_user.dart';

/// Authentication contract used by the presentation layer.
///
/// Implementations throw `AuthException` with a user-facing message on failure.
abstract interface class AuthService {
  /// Whether this build can authenticate (false when Firebase is missing).
  bool get isAvailable;

  /// The signed-in account, or `null` when signed out.
  AppUser? get currentUser;

  /// Emits the current account immediately and on every sign-in/out/profile change.
  Stream<AppUser?> authStateChanges();

  Future<AppUser> signInWithEmailAndPassword(String email, String password);

  /// Creates the account and stores [username] as its display name.
  Future<AppUser> registerWithEmailAndPassword(
    String email,
    String password,
    String username,
  );

  /// Returns `null` when the user dismisses the Google account picker.
  Future<AppUser?> signInWithGoogle({BuildContext? context});

  Future<void> signOut();
}
