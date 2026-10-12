import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/features/auth/data/services/local_auth_service.dart';
import 'package:seriolab/features/auth/domain/auth_exception.dart';
import 'package:seriolab/features/auth/domain/auth_validators.dart';
import 'package:seriolab/features/auth/domain/entities/app_user.dart';
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
        provider: AuthProviderKind.email,
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
  });

  group('AuthController Email Sign-In and Error Handling', () {
    test('successful email sign-in updates state', () async {
      final repo = InMemoryTrackingRepository();
      final localService = LocalAuthService(repo);
      await localService.registerWithEmailAndPassword(
        'tester@seriolab.app',
        'password123',
        'tester',
      );
      await localService.signOut();

      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(repo),
          authServiceProvider.overrideWithValue(localService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      final result = await notifier.signInWithEmail(
        email: 'tester@seriolab.app',
        password: 'password123',
      );

      expect(result, isTrue);
      final state = container.read(authControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.user?.email, 'tester@seriolab.app');
      expect(state.errorMessage, isNull);
      await Future<void>.delayed(Duration.zero);
    });

    test('failing email sign-in sets errorMessage', () async {
      final repo = InMemoryTrackingRepository();
      final localService = LocalAuthService(repo);

      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(repo),
          authServiceProvider.overrideWithValue(localService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      final result = await notifier.signInWithEmail(
        email: 'nonexistent@seriolab.app',
        password: 'password123',
      );

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNotNull);
      await Future<void>.delayed(Duration.zero);
    });
  });
}
