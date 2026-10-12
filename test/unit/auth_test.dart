import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/features/auth/data/services/firebase_auth_service.dart';
import 'package:seriolab/features/auth/data/services/local_auth_service.dart';
import 'package:seriolab/features/auth/domain/auth_exception.dart';
import 'package:seriolab/features/auth/domain/auth_validators.dart';
import 'package:seriolab/features/auth/domain/entities/app_user.dart';
import 'package:seriolab/features/auth/domain/services/auth_service.dart';
import 'package:seriolab/features/auth/presentation/providers/auth_providers.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';

void main() {
  group('AuthValidators', () {
    test('email validation works as expected', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('invalid-email'), isNotNull);
      expect(AuthValidators.email('user@seriolab'), isNotNull);
      expect(AuthValidators.email('utilizador@seriolab.app'), isNull);
    });

    test('password validation enforces minimum length', () {
      expect(AuthValidators.password(''), isNotNull);
      expect(AuthValidators.password('12345'), isNotNull);
      expect(AuthValidators.password('123456'), isNull);
    });

    test('confirmPassword matches original password', () {
      expect(AuthValidators.confirmPassword('', '123456'), isNotNull);
      expect(AuthValidators.confirmPassword('abcdef', '123456'), isNotNull);
      expect(AuthValidators.confirmPassword('123456', '123456'), isNull);
    });

    test('username validation and normalization', () {
      expect(AuthValidators.username(''), isNotNull);
      expect(AuthValidators.username('a'), isNotNull);
      expect(AuthValidators.username('user with spaces'), isNotNull);
      expect(AuthValidators.username('afonso_dias'), isNull);
      expect(AuthValidators.username('@afonso.dias'), isNull);
      expect(AuthValidators.normalizeUsername('@seriologo'), 'seriologo');
    });
  });

  group('AppUser', () {
    test('preferredName and suggestedUsername sanitization', () {
      const user = AppUser(
        uid: '123',
        email: 'joao.silva@example.com',
        provider: AuthProviderKind.email,
        displayName: 'João Silva',
      );

      expect(user.preferredName, 'João Silva');
      expect(user.suggestedUsername, 'joao_silva');

      const userNoName = AppUser(
        uid: '456',
        email: 'cinefilo@example.com',
        provider: AuthProviderKind.google,
      );

      expect(userNoName.preferredName, 'cinefilo');
      expect(userNoName.suggestedUsername, 'cinefilo');
    });
  });

  group('LocalAuthService', () {
    late InMemoryTrackingRepository repo;
    late LocalAuthService service;

    setUp(() {
      repo = InMemoryTrackingRepository();
      service = LocalAuthService(repo);
    });

    tearDown(() {
      service.dispose();
    });

    test('register, sign in, sign out lifecycle', () async {
      // 1. Register
      final registered = await service.registerWithEmailAndPassword(
        'tester@seriolab.app',
        'supersecret123',
        'tester_seriolab',
      );

      expect(registered.email, 'tester@seriolab.app');
      expect(service.currentUser?.email, 'tester@seriolab.app');

      // 2. Cannot register with duplicate email
      expect(
        () => service.registerWithEmailAndPassword(
          'tester@seriolab.app',
          'otherpassword',
          'other_user',
        ),
        throwsA(isA<AuthException>()),
      );

      // 3. Sign out
      await service.signOut();
      expect(service.currentUser, isNull);

      // 4. Sign in with wrong password fails
      expect(
        () => service.signInWithEmailAndPassword(
          'tester@seriolab.app',
          'wrongpass',
        ),
        throwsA(isA<AuthException>()),
      );

      // 5. Sign in with correct password succeeds
      final signedIn = await service.signInWithEmailAndPassword(
        'tester@seriolab.app',
        'supersecret123',
      );
      expect(signedIn.email, 'tester@seriolab.app');
      expect(service.currentUser?.email, 'tester@seriolab.app');
    });

    test('signInWithGoogle creates and sets active user', () async {
      final googleUser = await service.signInWithGoogle();
      expect(googleUser, isNotNull);
      expect(googleUser!.provider, AuthProviderKind.google);
      expect(service.currentUser?.provider, AuthProviderKind.google);
    });
  });

  group('FirebaseAuthService Configuration', () {
    test('defaultServerClientId matches Google Cloud Web Client ID', () {
      expect(
        FirebaseAuthService.defaultServerClientId,
        '686239497156-tp2m4tqbubp9ic3lq74parcok577mra2.apps.googleusercontent.com',
      );
    });
  });

  group('AuthController Google Sign-In State and Error Handling', () {
    test('cancelling Google Sign-In resets loading and does not set errorMessage', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            _MockConfigurableAuthService(cancelSelection: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      final result = await notifier.signInWithGoogle();

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('failing Google Sign-In with AuthException surfaces detailed error message', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            _MockConfigurableAuthService(
              exceptionToThrow: const AuthException(
                'Não foi possível obter tokens de autenticação do Google.',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      final result = await notifier.signInWithGoogle();

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.isLoading, isFalse);
      expect(
        state.errorMessage,
        'Não foi possível obter tokens de autenticação do Google.',
      );
    });

    test('failing Google Sign-In with unexpected exception surfaces descriptive feedback', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            _MockConfigurableAuthService(
              exceptionToThrow: Exception('Network error during Google auth'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      final result = await notifier.signInWithGoogle();

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, contains('Falha ao autenticar com o Google'));
    });
  });
}

class _MockConfigurableAuthService implements AuthService {
  _MockConfigurableAuthService({
    this.cancelSelection = false,
    this.exceptionToThrow,
  });

  final bool cancelSelection;
  final Object? exceptionToThrow;

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AppUser> registerWithEmailAndPassword(
    String email,
    String password,
    String username,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> signInWithEmailAndPassword(String email, String password) {
    throw UnimplementedError();
  }

  @override
  Future<AppUser?> signInWithGoogle({BuildContext? context}) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (cancelSelection) {
      return null;
    }
    return const AppUser(
      uid: 'google-uid-123',
      email: 'test@gmail.com',
      provider: AuthProviderKind.google,
    );
  }

  @override
  Future<void> signOut() async {}
}
