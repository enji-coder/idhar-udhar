import 'dart:async';
import 'dart:developer';

import 'package:idhar_udhar/shared/api/api_config.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import 'rider_online_presence.dart';
import 'rider_presence_tick.dart';

/// Publishes rider GPS to POST /v1/rider/location and keeps Online presence
/// alive. While the dashboard is resumed, Dart timers backstop the native
/// foreground service. When the app is backgrounded, only the FGS continues.
class RiderLocationPublisher {
  RiderLocationPublisher({
    required DeviceLocationService location,
    required RiderApi api,
    required TokenStore tokens,
  })  : _location = location,
        _api = api,
        _tokens = tokens;

  final DeviceLocationService _location;
  final RiderApi _api;
  final TokenStore _tokens;
  Timer? _timer;
  bool _started = false;
  bool _tickInFlight = false;
  bool _askedForPermission = false;
  bool _loggedPermissionSkip = false;
  double? _lastLat;
  double? _lastLng;

  Future<void> start() async {
    final bool first = !_started;
    _started = true;
    final bool ask = !_askedForPermission;
    _askedForPermission = true;
    final LocationResult probe =
        await _location.currentLocation(requestPermission: ask);
    if (probe.isOk) {
      _lastLat = probe.location!.latitude;
      _lastLng = probe.location!.longitude;
    }
    // Permission must be granted before the location FGS. A missing grant
    // must not start it (Android 14 SecurityException) or look like presence.
    if (riderLocationPermissionAllowsForegroundService(probe.failure)) {
      _loggedPermissionSkip = false;
      await _syncNativePresence();
    } else if (!_loggedPermissionSkip) {
      _loggedPermissionSkip = true;
      log(
        'rider_online_presence_not_started reason=location_permission_missing',
        name: 'rider_location',
      );
    }
    if (!first) {
      return;
    }
    unawaited(_tick());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_tick());
    });
  }

  Future<void> stop() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    await RiderOnlinePresence.stop();
  }

  Future<void> _syncNativePresence() async {
    final String? token = await _tokens.accessToken;
    if (token == null || token.trim().isEmpty) {
      return;
    }
    await RiderOnlinePresence.start(
      accessToken: token,
      baseUrl: ApiConfig.baseUrl,
    );
  }

  Future<void> _tick() async {
    if (!_started || _tickInFlight) {
      return;
    }
    _tickInFlight = true;
    try {
      await _publishTick();
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> _publishTick() async {
    if (!_started) {
      return;
    }
    final bool ask = !_askedForPermission;
    _askedForPermission = true;
    final LocationResult result =
        await _location.currentLocation(requestPermission: ask);
    if (result.isOk) {
      _lastLat = result.location!.latitude;
      _lastLng = result.location!.longitude;
    }
    final RiderPresenceTickAction action = riderPresenceTickAction(
      gpsOk: result.isOk,
      hasLastKnown: _lastLat != null && _lastLng != null,
    );
    switch (action) {
      case RiderPresenceTickAction.postFreshGps:
      case RiderPresenceTickAction.repostLastKnown:
        try {
          await _api.postLocation(
            latitude: _lastLat!,
            longitude: _lastLng!,
          );
          return;
        } on ApiException catch (error) {
          log(
            'rider_location_post_failed code=${error.code} status=${error.statusCode}',
            name: 'rider_location',
          );
        }
      case RiderPresenceTickAction.heartbeatOnly:
        break;
    }
    try {
      await _api.postPresenceHeartbeat();
    } on ApiException catch (error) {
      log(
        'rider_presence_heartbeat_failed code=${error.code}',
        name: 'rider_location',
      );
    }
  }
}
