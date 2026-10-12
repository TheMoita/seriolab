import 'package:flutter/foundation.dart';

/// How the user authenticated with Seriolab.
enum AuthProviderKind {
  email('Email and password'),
  google('Google');

  const AuthProviderKind(this.label);

  final String label;
}

/// Framework-agnostic view of an authenticated account.
///
/// Decouples the UI from `firebase_auth`'s `User` so screens and tests never
/// depend on Firebase directly.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.provider,
    this.displayName,
    this.photoUrl,
    this.profileBannerUrl,
    this.profileBannerPath,
  });

  final String uid;
  final String email;
  final AuthProviderKind provider;
  final String? displayName;
  final String? photoUrl;
  final String? profileBannerUrl;
  final String? profileBannerPath;

  bool get hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;
  bool get hasCustomBanner =>
      (profileBannerUrl != null && profileBannerUrl!.trim().isNotEmpty) ||
      (profileBannerPath != null && profileBannerPath!.trim().isNotEmpty);

  /// Best human-readable name: account display name, else the email prefix.
  String get preferredName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final local = email.split('@').first;
    return local.isEmpty ? 'Seriólogo' : local;
  }

  /// A Seriolab-compatible `@username` derived from the account details.
  String get suggestedUsername => sanitizeUsername(displayName ?? email.split('@').first);

  /// Lowercases, strips diacritics/unsupported characters and clamps length.
  static String sanitizeUsername(String raw) {
    const accents = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final char in raw.trim().toLowerCase().split('')) {
      final mapped = accents[char] ?? char;
      if (RegExp(r'[a-z0-9_.]').hasMatch(mapped)) {
        buffer.write(mapped);
      } else if (mapped == ' ' || mapped == '-') {
        buffer.write('_');
      }
    }
    var result = buffer.toString().replaceAll(RegExp(r'_+'), '_');
    if (result.length > 20) result = result.substring(0, 20);
    return result.length < 3 ? 'seriologo' : result;
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.provider == provider &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.profileBannerUrl == profileBannerUrl &&
      other.profileBannerPath == profileBannerPath;

  @override
  int get hashCode => Object.hash(
        uid,
        email,
        provider,
        displayName,
        photoUrl,
        profileBannerUrl,
        profileBannerPath,
      );
}
