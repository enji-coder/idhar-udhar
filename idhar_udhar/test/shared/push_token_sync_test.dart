import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/push/push_token_sync.dart';

void main() {
  test('empty token does not call registration', () async {
    final _FakeSink sink = _FakeSink();
    final _FakeSource source = _FakeSource(null);
    final PushTokenSync sync = PushTokenSync.testing(
      sink,
      tokens: source,
      requireFirebase: true,
      releaseMode: true,
      definedToken: 'must-not-be-used',
    );

    await sync.syncAfterAuth();

    expect(sink.registered, isEmpty);
    sync.dispose();
  });

  test('real token is passed to the device token API', () async {
    final _FakeSink sink = _FakeSink();
    final _FakeSource source = _FakeSource('real-fcm-token-value');
    final PushTokenSync sync = PushTokenSync.testing(
      sink,
      tokens: source,
      requireFirebase: true,
      releaseMode: true,
      definedToken: 'staging-token-should-lose',
    );

    await sync.syncAfterAuth();
    await sync.syncAfterAuth();

    expect(sink.registered, <String>['ANDROID:real-fcm-token-value']);
    expect(source.permissionCalls, 1);
    sync.dispose();
  });

  test('logout unregisters only the registered token', () async {
    final _FakeSink sink = _FakeSink();
    final _FakeSource source = _FakeSource('registered-token-value');
    final PushTokenSync sync = PushTokenSync.testing(sink, tokens: source);

    await sync.syncAfterAuth();
    await sync.unregisterOnLogout();
    await sync.unregisterOnLogout();

    expect(sink.unregistered, <String>['registered-token-value']);
    sync.dispose();
  });

  test('token refresh registers when authenticated and replaces local token', () async {
    final _FakeSink sink = _FakeSink();
    final _FakeSource source = _FakeSource('original-token-value');
    final PushTokenSync sync = PushTokenSync.testing(sink, tokens: source);

    source.refreshes.add('early-refresh-token');
    await pumpEventQueue();
    expect(sink.registered, isEmpty);

    await sync.syncAfterAuth();
    source.refreshes.add('refreshed-token-value');
    await pumpEventQueue();

    expect(
      sink.registered,
      <String>[
        'ANDROID:original-token-value',
        'ANDROID:refreshed-token-value',
      ],
    );

    await sync.unregisterOnLogout();
    expect(sink.unregistered, <String>['refreshed-token-value']);
    sync.dispose();
  });

  test('registration failure does not throw or mark the token registered', () async {
    final _FakeSink sink = _FakeSink()..registerError = StateError('offline');
    final _FakeSource source = _FakeSource('real-fcm-token-value');
    final PushTokenSync sync = PushTokenSync.testing(sink, tokens: source);

    await expectLater(sync.syncAfterAuth(), completes);
    await sync.unregisterOnLogout();

    expect(sink.registerCalls, 1);
    expect(sink.unregistered, isEmpty);
    sync.dispose();
  });
}

class _FakeSource implements FcmTokenSource {
  _FakeSource(this.token);

  String? token;
  final StreamController<String> refreshes = StreamController<String>.broadcast();
  int permissionCalls = 0;

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get tokenRefresh => refreshes.stream;

  @override
  Future<String> requestNotificationPermission() async {
    permissionCalls += 1;
    return 'denied';
  }
}

class _FakeSink implements DeviceTokenSink {
  final List<String> registered = <String>[];
  final List<String> unregistered = <String>[];
  Object? registerError;
  int registerCalls = 0;

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    registerCalls += 1;
    final Object? error = registerError;
    if (error != null) {
      throw error;
    }
    registered.add('$platform:$token');
  }

  @override
  Future<void> unregister(String token) async {
    unregistered.add(token);
  }
}
