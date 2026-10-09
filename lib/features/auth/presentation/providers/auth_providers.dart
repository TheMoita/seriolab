import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../tracking/domain/repositories/tracking_repository.dart';
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

/// State representation for app-wide authentication and guest mode.
class AuthState {
  const AuthState({
    this.user,
    this.isGuest = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final AppUser? user;
  final bool isGuest;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;
  bool get canAccessApp => isAuthenticated || isGuest;

  AuthState copyWith({
    AppUser? user,
    bool clearUser = false,
    bool? isGuest,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller managing login, registration, guest mode, and profile synchronization.
class AuthController extends Notifier<AuthState> {
  static const String _guestKey = 'seriolab_guest_mode';

  AuthService get _service => ref.read(authServiceProvider);
  TrackingRepository get _trackingRepo => ref.read(trackingRepositoryProvider);

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
        }
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    final initialUser = service.currentUser;
    _checkPersistedGuestMode();

    return AuthState(user: initialUser);
  }

  Future<void> _checkPersistedGuestMode() async {
    try {
      final flag = await _trackingRepo.readMeta(_guestKey);
      if (flag == 'true' && state.user == null) {
        state = state.copyWith(isGuest: true);
      }
    } catch (_) {}
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Guest mode allows browsing the catalog without an account.
  Future<void> continueAsGuest() async {
    state = state.copyWith(isGuest: true, clearError: true);
    try {
      await _trackingRepo.writeMeta(_guestKey, 'true');
    } catch (_) {}
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.signInWithEmailAndPassword(email, password);
      await _trackingRepo.writeMeta(_guestKey, 'false');
      state = state.copyWith(
        user: user,
        isGuest: false,
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
      await _trackingRepo.writeMeta(_guestKey, 'false');
      state = state.copyWith(
        user: user,
        isGuest: false,
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
        // User cancelled picker
        state = state.copyWith(isLoading: false);
        return false;
      }
      await _trackingRepo.writeMeta(_guestKey, 'false');
      state = state.copyWith(
        user: user,
        isGuest: false,
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
        errorMessage: 'Erro ao autenticar com Google: $e',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.signOut();
      await _trackingRepo.writeMeta(_guestKey, 'false');
    } finally {
      state = const AuthState(
        user: null,
        isGuest: false,
        isLoading: false,
      );
    }
  }

  Future<void> _syncUserToProfile(AppUser user, {String? customUsername}) async {
    try {
      final notifier = ref.read(settingsControllerProvider.notifier);
      final current = ref.read(settingsControllerProvider);

      final displayName = user.preferredName;
      final username = customUsername ??
          (current.username.isEmpty || current.username == 'afonsodias'
              ? user.suggestedUsername
              : current.username);

      await notifier.updateProfile(
        displayName: displayName,
        username: username,
        bio: current.bio.isEmpty
            ? 'Membro Seriolab via ${user.provider.label}.'
            : current.bio,
        avatarId: current.avatarId,
      );
    } catch (_) {}
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
