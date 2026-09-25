import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/state/session_provider.dart';
import 'package:idhar_udhar/shared/api/api_client.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/auth_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokenStore extends TokenStore {
  _MemoryTokenStore({this.access, this.refresh, this.phoneValue});

  String? access;
  String? refresh;
  String? phoneValue;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<String?> get phone async => phoneValue;

  @override
  Future<bool> get hasRefreshToken async =>
      refresh != null && refresh!.isNotEmpty;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? role,
    String? phone,
  }) async {
    access = accessToken;
    refresh = refreshToken;
    phoneValue = phone ?? phoneValue;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    phoneValue = null;
  }
}

class _HangingTokenStore extends _MemoryTokenStore {
  _HangingTokenStore() : super(refresh: 'pending');

  @override
  Future<bool> get hasRefreshToken => Completer<bool>().future;
}

class _ThrowingAuthApi extends AuthApi {
  _ThrowingAuthApi(this._error)
      : super(
          ApiClient(tokenStore: _MemoryTokenStore()),
          _MemoryTokenStore(),
        );

  final ApiException _error;

  @override
  Future<AuthSession> session() async {
    throw _error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('hydrate with no refresh token finishes unauthenticated', () async {
    final SessionNotifier notifier = SessionNotifier(
      tokenStore: _MemoryTokenStore(),
      authApi: AuthApi(
        ApiClient(tokenStore: _MemoryTokenStore()),
        _MemoryTokenStore(),
      ),
    );

    await notifier.hydrate(timeout: const Duration(seconds: 2));

    expect(notifier.state.isHydrated, isTrue);
    expect(notifier.state.isAuthenticated, isFalse);
  });

  test('hydrate times out instead of waiting forever', () async {
    final _HangingTokenStore tokens = _HangingTokenStore();
    final SessionNotifier notifier = SessionNotifier(
      tokenStore: tokens,
      authApi: AuthApi(ApiClient(tokenStore: tokens), tokens),
    );

    await notifier.hydrate(timeout: const Duration(milliseconds: 50));

    expect(notifier.state.isHydrated, isTrue);
    expect(notifier.state.isAuthenticated, isFalse);
  });

  test('expired session is cleared and finishes unauthenticated', () async {
    final _MemoryTokenStore tokens = _MemoryTokenStore(
      access: 'expired-access',
      refresh: 'expired-refresh',
      phoneValue: '9876543210',
    );
    final SessionNotifier notifier = SessionNotifier(
      tokenStore: tokens,
      authApi: _ThrowingAuthApi(
        const ApiException(
          code: 'UNAUTHENTICATED',
          message: 'Please sign in again.',
        ),
      ),
    );

    await notifier.hydrate(timeout: const Duration(seconds: 2));

    expect(notifier.state.isHydrated, isTrue);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(await tokens.hasRefreshToken, isFalse);
  });

  test('API outage does not wipe tokens or stay loading', () async {
    final _MemoryTokenStore tokens = _MemoryTokenStore(
      access: 'access',
      refresh: 'refresh',
      phoneValue: '9876543210',
    );
    final SessionNotifier notifier = SessionNotifier(
      tokenStore: tokens,
      authApi: _ThrowingAuthApi(
        const ApiException(
          code: 'DATABASE_UNAVAILABLE',
          message: 'Cannot reach the server. Check your connection.',
        ),
      ),
    );

    await notifier.hydrate(timeout: const Duration(seconds: 2));

    expect(notifier.state.isHydrated, isTrue);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(await tokens.hasRefreshToken, isTrue);
  });
}
