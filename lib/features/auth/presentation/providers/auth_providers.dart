import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/local_auth_service.dart';
import '../../domain/auth_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/services/auth_service.dart';

/// Provider for the active [AuthService].
///
/// Falls back to [LocalAuthService] if Firebase has not been initialized
/// (e.g. in tests, web without options, or CI without google-services.json).
final authServiceProvider = Provider<AuthService>((ref) {
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  if (Firebase.apps.isNotEmpty) {
    try {
      return FirebaseAuthService(auth: FirebaseAuth.instance);
    } catch (_) {}
  }
  return LocalAuthService(trackingRepo);
});

/// Stream of authentication state changes.
final authUserStreamProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

/// State representation for app-wide authentication.
class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;
  bool get canAccessApp => isAuthenticated;

  AuthState copyWith({
    AppUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller managing login, registration, and profile synchronization.
class AuthController extends Notifier<AuthState> {
  AuthService get _service => ref.read(authServiceProvider);

  StreamSubscription<AppUser?>? _subscription;

  @override
  AuthState build() {
    final service = ref.watch(authServiceProvider);

    // Listen to background auth state changes
    _subscription?.cancel();
    _subscription = service.authStateChanges().listen((user) {
      if (state.user != user) {
        state = state.copyWith(user: user, clearUser: user == null);
        if (user != null) {
          _syncUserToProfile(user);
        } else {
          _stopFirestoreSync();
        }
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    final initialUser = service.currentUser;
    if (initialUser != null) {
      Future.microtask(() {
        _triggerFirestoreSync(initialUser.uid);
      });
    }
    return AuthState(user: initialUser);
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.signInWithEmailAndPassword(email, password);
      state = state.copyWith(
        user: user,
        isLoading: false,
        clearError: true,
      );
      await _syncUserToProfile(user);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro inesperado ao iniciar sessão: $e',
      );
      return false;
    }
  }

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.registerWithEmailAndPassword(
        email,
        password,
        username,
      );
      state = state.copyWith(
        user: user,
        isLoading: false,
        clearError: true,
      );
      await _syncUserToProfile(user, customUsername: username);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro inesperado ao registar conta: $e',
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.signInWithGoogle();
      if (user == null) {
        // Utilizador cancelou a seleção
        state = state.copyWith(isLoading: false);
        return false;
      }
      state = state.copyWith(
        user: user,
        isLoading: false,
        clearError: true,
      );
      await _syncUserToProfile(user);
      return true;
    } on AuthException catch (e) {
      debugPrint(
        'Erro detalhado no Google Sign-In (AuthController AuthException): ${e.message}',
      );
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      debugPrint('Erro detalhado no Google Sign-In (AuthController): $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Falha ao autenticar com o Google: $e',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      _stopFirestoreSync();
      await _service.signOut();
    } finally {
      state = const AuthState(
        user: null,
        isLoading: false,
      );
    }
  }

  Future<void> _syncUserToProfile(AppUser user, {String? customUsername}) async {
    // Only update local profile immediately if customUsername was explicitly provided (e.g., registration).
    // Avoid overwriting settings with default local values before Firestore sync downloads cloud state.
    if (customUsername != null && customUsername.isNotEmpty) {
      try {
        final notifier = ref.read(settingsControllerProvider.notifier);
        final current = ref.read(settingsControllerProvider);
        await notifier.updateProfile(
          displayName: user.preferredName,
          username: customUsername,
          bio: current.bio,
          avatarId: current.avatarId,
        );
      } catch (_) {}
    }
    _triggerFirestoreSync(user.uid);
  }

  void _triggerFirestoreSync(String uid) {
    try {
      final syncService = ref.read(firestoreSyncServiceProvider);
      final trackingController = ref.read(trackingControllerProvider.notifier);
      final settingsNotifier = ref.read(settingsControllerProvider.notifier);
      syncService.syncUser(
        uid,
        trackingController: trackingController,
        settingsNotifier: settingsNotifier,
      );
    } catch (e) {
      debugPrint('AuthController: Firestore sync trigger note: $e');
    }
  }

  void _stopFirestoreSync() {
    try {
      ref.read(firestoreSyncServiceProvider).stopSync();
    } catch (_) {}
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
