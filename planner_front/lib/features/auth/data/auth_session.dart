import 'package:flutter/foundation.dart';

import 'auth_api.dart';
import 'auth_storage.dart';

class AuthSession extends ChangeNotifier {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const Duration _refreshMargin =
      Duration(seconds: 45);

  final AuthApi _authApi = AuthApi();
  final AuthStorage _storage = const AuthStorage();

  StoredAuthSession? _session;
  Future<bool>? _refreshFuture;
  Future<void>? _initializeFuture;

  bool _isInitialized = false;
  bool _isBusy = false;

  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;
  bool get isAuthenticated => _session != null;
  String? get email => _session?.email;

  Future<void> initialize() {
    final current = _initializeFuture;

    if (current != null) {
      return current;
    }

    final future = _initializeInternal();
    _initializeFuture = future;

    return future;
  }

  Future<void> _initializeInternal() async {
    try {
      _session = await _storage.readSession();

      if (_session != null && _isAccessTokenExpiringSoon) {
        await refreshTokens(force: true);
      }
    } catch (_) {
      _session = null;

      try {
        await _storage.clear();
      } catch (_) {
        // Le stockage ne doit pas empêcher l'application de démarrer.
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _setBusy(true);

    try {
      final tokens = await _authApi.login(
        email: email,
        password: password,
      );

      final session = _createStoredSession(
        tokens,
        email: email.trim(),
      );

      await _storage.writeSession(session);

      _session = session;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    _session = null;
    notifyListeners();

    try {
      await _storage.clear();
    } catch (_) {
      // La session mémoire est déjà fermée.
    }
  }

  Future<String?> getValidAccessToken() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_session == null) {
      return null;
    }

    if (_isAccessTokenExpiringSoon) {
      final refreshed =
          await refreshTokens(force: true);

      if (!refreshed) {
        return null;
      }
    }

    return _session?.accessToken;
  }

  Future<bool> refreshTokens({
    bool force = false,
  }) async {
    final currentRefresh = _refreshFuture;

    if (currentRefresh != null) {
      return currentRefresh;
    }

    final future =
        _refreshTokensInternal(force: force);
    _refreshFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  Future<bool> _refreshTokensInternal({
    required bool force,
  }) async {
    final currentSession = _session;

    if (currentSession == null) {
      return false;
    }

    if (!force && !_isAccessTokenExpiringSoon) {
      return true;
    }

    try {
      final tokens = await _authApi.refresh(
        refreshToken: currentSession.refreshToken,
      );

      final refreshedSession = _createStoredSession(
        tokens,
        email: currentSession.email,
      );

      await _storage.writeSession(refreshedSession);

      _session = refreshedSession;
      notifyListeners();

      return true;
    } on AuthException catch (error) {
      if (error.shouldClearSession) {
        await logout();
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  bool get _isAccessTokenExpiringSoon {
    final session = _session;

    if (session == null) {
      return true;
    }

    final refreshAt =
        session.expiresAt.subtract(_refreshMargin);

    return !DateTime.now().toUtc().isBefore(refreshAt);
  }

  StoredAuthSession _createStoredSession(
    AuthTokenResponse tokens, {
    required String? email,
  }) {
    return StoredAuthSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      tokenType: tokens.tokenType,
      expiresAt: DateTime.now()
          .toUtc()
          .add(Duration(seconds: tokens.expiresIn)),
      email: email,
    );
  }

  void _setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }

    _isBusy = value;
    notifyListeners();
  }
}
