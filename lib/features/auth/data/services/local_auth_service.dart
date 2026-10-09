import 'dart:async';
import 'dart:convert';

import '../../../tracking/domain/repositories/tracking_repository.dart';
import '../../domain/auth_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/services/auth_service.dart';

/// Local offline-first implementation of [AuthService].
///
/// Stores registered accounts and current session in [TrackingRepository]
/// metadata (`app_meta`). Used as fallback when Firebase credentials
/// are absent (such as in local CI / dev without `google-services.json`)
/// and for offline testing.
class LocalAuthService implements AuthService {
  LocalAuthService(this._trackingRepo) {
    _init();
  }

  final TrackingRepository _trackingRepo;
  final _controller = StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  bool _initialized = false;

  static const _currentKey = 'seriolab_auth_current_user';
  static const _accountsKey = 'seriolab_auth_accounts';

  Future<void> _init() async {
    try {
      final raw = await _trackingRepo.readMeta(_currentKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _currentUser = _mapUser(map);
      }
    } catch (_) {
      _currentUser = null;
    } finally {
      _initialized = true;
      _controller.add(_currentUser);
    }
  }

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (_initialized) {
      yield _currentUser;
    }
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final cleanEmail = email.trim().toLowerCase();
    final accounts = await _loadAccounts();

    final account = accounts[cleanEmail];
    if (account == null) {
      throw const AuthException(
        'Nenhuma conta encontrada com este email. Regista-te primeiro.',
        code: 'user-not-found',
      );
    }

    if (account['password'] != password) {
      throw const AuthException(
        'Email ou palavra-passe incorretos.',
        code: 'wrong-password',
      );
    }

    final user = AppUser(
      uid: account['uid'] as String,
      email: cleanEmail,
      provider: AuthProviderKind.email,
      displayName: account['displayName'] as String?,
    );

    await _saveCurrent(user);
    return user;
  }

  @override
  Future<AppUser> registerWithEmailAndPassword(
    String email,
    String password,
    String username,
  ) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = AppUser.sanitizeUsername(username);
    final accounts = await _loadAccounts();

    if (accounts.containsKey(cleanEmail)) {
      throw const AuthException(
        'Já existe uma conta associada a este email.',
        code: 'email-already-in-use',
      );
    }

    final uid = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final userMap = {
      'uid': uid,
      'email': cleanEmail,
      'password': password,
      'displayName': cleanUsername,
      'provider': 'email',
    };

    accounts[cleanEmail] = userMap;
    await _saveAccounts(accounts);

    final user = AppUser(
      uid: uid,
      email: cleanEmail,
      provider: AuthProviderKind.email,
      displayName: cleanUsername,
    );

    await _saveCurrent(user);
    return user;
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    // Simulated Google Sign-In for offline / dev preview
    const email = 'utilizador.google@seriolab.app';
    final user = AppUser(
      uid: 'google_offline_user',
      email: email,
      provider: AuthProviderKind.google,
      displayName: 'Utilizador Google',
      photoUrl: null,
    );

    await _saveCurrent(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _trackingRepo.writeMeta(_currentKey, '');
    _controller.add(null);
  }

  Future<void> _saveCurrent(AppUser user) async {
    _currentUser = user;
    final map = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      'provider': user.provider.name,
    };
    await _trackingRepo.writeMeta(_currentKey, jsonEncode(map));
    _controller.add(user);
  }

  Future<Map<String, Map<String, dynamic>>> _loadAccounts() async {
    try {
      final raw = await _trackingRepo.readMeta(_accountsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveAccounts(Map<String, Map<String, dynamic>> accounts) async {
    await _trackingRepo.writeMeta(_accountsKey, jsonEncode(accounts));
  }

  AppUser _mapUser(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String? ?? 'user_local',
      email: map['email'] as String? ?? '',
      provider: map['provider'] == 'google'
          ? AuthProviderKind.google
          : AuthProviderKind.email,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
    );
  }

  void dispose() {
    _controller.close();
  }
}
