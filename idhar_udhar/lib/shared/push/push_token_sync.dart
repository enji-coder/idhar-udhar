import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../api/device_tokens_api.dart';

/// Reads a real FCM registration token. Production Rider passes
/// [FirebaseFcmTokenSource]; tests pass a fake.
abstract class FcmTokenSource {
  Future<String?> currentToken();
  Stream<String> get tokenRefresh;
  Future<String> requestNotificationPermission();
}

/// Backend device-token register/unregister seam used by [PushTokenSync].
abstract class DeviceTokenSink {
  Future<void> register({required String token, required String platform});
  Future<void> unregister(String token);
}

class _ApiDeviceTokenSink implements DeviceTokenSink {
  _ApiDeviceTokenSink(this._api);

  final DeviceTokensApi _api;

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) {
    return _api.register(token: token, platform: platform);
  }

  @override
  Future<void> unregister(String token) => _api.unregister(token);
}

/// Syncs an FCM device token with Nest `POST /v1/device-tokens`.
///
/// Rider production uses the Firebase token from [FcmTokenSource].
/// `IU_FCM_TOKEN` remains a non-release fallback and never replaces a real
/// Firebase token. This class never invents a token.
class PushTokenSync {
  PushTokenSync(
    DeviceTokensApi api, {
    FcmTokenSource? tokens,
    bool requireFirebase = false,
  }) : this._(
          _ApiDeviceTokenSink(api),
          tokens: tokens,
          requireFirebase: requireFirebase,
        );

  @visibleForTesting
  PushTokenSync.testing(
    DeviceTokenSink sink, {
    FcmTokenSource? tokens,
    bool requireFirebase = false,
    String definedToken = '',
    bool releaseMode = false,
  }) : this._(
          sink,
          tokens: tokens,
          requireFirebase: requireFirebase,
          definedToken: definedToken,
          releaseMode: releaseMode,
        );

  PushTokenSync._(
    this._sink, {
    required this.requireFirebase,
    FcmTokenSource? tokens,
    this.definedToken = const String.fromEnvironment('IU_FCM_TOKEN'),
    this.releaseMode = kReleaseMode,
  }) : _tokens = tokens {
    _ensureListening();
  }

  final DeviceTokenSink _sink;
  final FcmTokenSource? _tokens;
  final bool requireFirebase;

  /// Compile-time staging token. Ignored when a Firebase token is present,
  /// and ignored for release Rider builds.
  final String definedToken;
  final bool releaseMode;

  String? _registeredToken;
  bool _authenticated = false;
  bool _listening = false;
  bool _permissionRequested = false;
  StreamSubscription<String>? _refreshSub;
  Future<void>? _inFlight;
  String? _inFlightToken;

  /// Registers the current token after a Rider or Customer session exists.
  ///
  /// Network and Firebase failures are logged and do not throw.
  Future<void> syncAfterAuth() async {
    _authenticated = true;
    await _requestPermissionOnce();
    final String? token = await _resolveToken();
    if (!_authenticated) {
      return;
    }
    if (token == null || token.isEmpty) {
      _debug('PUSH: token not obtained');
      return;
    }
    await _registerToken(token);
  }

  /// Unregisters only the token this session successfully registered.
  ///
  /// Customer builds without Firebase still unregister a staging
  /// `IU_FCM_TOKEN` when that was the token sent at login.
  Future<void> unregisterOnLogout() async {
    _authenticated = false;
    final String fallback = _tokens == null ? definedToken : '';
    final String token = (_registeredToken ?? fallback).trim();
    _registeredToken = null;
    if (token.isEmpty) {
      return;
    }
    try {
      await _sink.unregister(token);
      _debug('PUSH: token unregistered');
    } catch (error) {
      _debug('PUSH: unregister failed: $error');
    }
  }

  void dispose() {
    _refreshSub?.cancel();
    _refreshSub = null;
    _listening = false;
  }

  void _ensureListening() {
    final FcmTokenSource? source = _tokens;
    if (source == null || _listening) {
      return;
    }
    _listening = true;
    _refreshSub = source.tokenRefresh.listen(
      (String token) {
        if (!_authenticated) {
          _debug('PUSH: token refresh detected while signed out');
          return;
        }
        _debug('PUSH: token refresh detected');
        unawaited(_registerToken(token));
      },
      onError: (Object error) {
        _debug('PUSH: token refresh failed: $error');
      },
    );
  }

  Future<void> _requestPermissionOnce() async {
    final FcmTokenSource? source = _tokens;
    if (source == null || _permissionRequested) {
      return;
    }
    _permissionRequested = true;
    try {
      final String status = await source.requestNotificationPermission();
      _debug('PUSH: permission status: $status');
      if (status == 'denied') {
        _debug(
          'PUSH: notification permission denied; login continues',
        );
      }
    } catch (error) {
      _debug('PUSH: permission request failed: $error');
    }
  }

  Future<String?> _resolveToken() async {
    final FcmTokenSource? source = _tokens;
    if (source != null) {
      try {
        final String live = (await source.currentToken())?.trim() ?? '';
        if (live.isNotEmpty) {
          _debug('PUSH: token obtained (${_mask(live)})');
          return live;
        }
      } catch (error) {
        _debug('PUSH: token retrieval failed: $error');
      }
    } else if (requireFirebase) {
      _debug('PUSH: Firebase not initialized');
    }
    if (requireFirebase && releaseMode) {
      return null;
    }
    final String defined = definedToken.trim();
    return defined.isEmpty ? null : defined;
  }

  Future<void> _registerToken(String token) {
    final String trimmed = token.trim();
    if (!_authenticated || trimmed.isEmpty || trimmed == _registeredToken) {
      return Future<void>.value();
    }
    if (_inFlight != null && _inFlightToken == trimmed) {
      return _inFlight!;
    }
    final Future<void> flight = _send(trimmed);
    _inFlight = flight;
    _inFlightToken = trimmed;
    return flight.whenComplete(() {
      if (identical(_inFlight, flight)) {
        _inFlight = null;
        _inFlightToken = null;
      }
    });
  }

  Future<void> _send(String token) async {
    if (!_authenticated) {
      return;
    }
    _debug('PUSH: registration attempted (${_mask(token)})');
    try {
      await _sink.register(token: token, platform: _platformLabel());
      if (!_authenticated) {
        try {
          await _sink.unregister(token);
        } catch (error) {
          _debug('PUSH: unregister failed: $error');
        }
        return;
      }
      _registeredToken = token;
      _debug('PUSH: registration succeeded (${_mask(token)})');
    } catch (error) {
      _debug('PUSH: registration failed: $error');
    }
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'WEB';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
        return 'ANDROID';
      default:
        return 'ANDROID';
    }
  }

  void _debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  String _mask(String token) {
    if (token.length <= 8) {
      return '****';
    }
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }
}

final pushTokenSyncProvider = Provider<PushTokenSync>((ref) {
  final PushTokenSync sync = PushTokenSync(ref.watch(deviceTokensApiProvider));
  ref.onDispose(sync.dispose);
  return sync;
});
