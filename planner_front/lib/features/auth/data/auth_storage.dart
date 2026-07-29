import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const String _accessTokenKey =
      'planner.auth.access_token';
  static const String _refreshTokenKey =
      'planner.auth.refresh_token';
  static const String _tokenTypeKey =
      'planner.auth.token_type';
  static const String _expiresAtKey =
      'planner.auth.expires_at';
  static const String _emailKey =
      'planner.auth.email';

  final FlutterSecureStorage _storage;

  const AuthStorage({
    this._storage = const FlutterSecureStorage(),
  });

  Future<StoredAuthSession?> readSession() async {
    final accessToken =
        await _storage.read(key: _accessTokenKey);
    final refreshToken =
        await _storage.read(key: _refreshTokenKey);
    final tokenType =
        await _storage.read(key: _tokenTypeKey);
    final expiresAtText =
        await _storage.read(key: _expiresAtKey);
    final email =
        await _storage.read(key: _emailKey);

    final expiresAt = expiresAtText == null
        ? null
        : DateTime.tryParse(expiresAtText);

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        expiresAt == null) {
      return null;
    }

    return StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType:
          tokenType?.isNotEmpty == true ? tokenType! : 'Bearer',
      expiresAt: expiresAt.toUtc(),
      email: email,
    );
  }

  Future<void> writeSession(
    StoredAuthSession session,
  ) async {
    await Future.wait<void>([
      _storage.write(
        key: _accessTokenKey,
        value: session.accessToken,
      ),
      _storage.write(
        key: _refreshTokenKey,
        value: session.refreshToken,
      ),
      _storage.write(
        key: _tokenTypeKey,
        value: session.tokenType,
      ),
      _storage.write(
        key: _expiresAtKey,
        value: session.expiresAt
            .toUtc()
            .toIso8601String(),
      ),
      _storage.write(
        key: _emailKey,
        value: session.email,
      ),
    ]);
  }

  Future<void> clear() async {
    await Future.wait<void>([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _tokenTypeKey),
      _storage.delete(key: _expiresAtKey),
      _storage.delete(key: _emailKey),
    ]);
  }
}

class StoredAuthSession {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;
  final String? email;

  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
    required this.email,
  });
}
