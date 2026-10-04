import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../data/mock/mock_models.dart';
import 'booking_draft_provider.dart';

bool _deviceLocationWarmInFlight = false;

/// One-shot GPS warm-up into [BookingDraft.deviceLocation].
///
/// Does not request permission (avoids racing the education screen), does not
/// start a continuous listener, and skips work when a usable cache already
/// exists. Safe to call from app start and again when Home becomes active.
Future<void> warmCachedDeviceLocation({
  required DeviceLocationService service,
  required BookingDraftNotifier draft,
  required MockLocation? Function() readDeviceLocation,
}) async {
  if (_deviceLocationWarmInFlight) {
    return;
  }
  final MockLocation? existing = readDeviceLocation();
  if (existing?.latitude != null &&
      existing?.longitude != null &&
      existing!.address.trim().isNotEmpty) {
    return;
  }

  _deviceLocationWarmInFlight = true;
  try {
    if (existing?.latitude != null && existing?.longitude != null) {
      final GeoPoint point = GeoPoint(
        latitude: existing!.latitude!,
        longitude: existing.longitude!,
      );
      final ResolvedAddress? resolved = await service.reverse(point);
      final String formatted = resolved?.address.trim() ?? '';
      if (formatted.isEmpty) {
        return;
      }
      draft.applyDevicePickup(
        existing.copyWith(
          label: formatted,
          address: formatted,
          city: resolved?.city ?? existing.city,
        ),
      );
      return;
    }

    final LocationResult result =
        await service.currentLocation(requestPermission: false);
    if (!result.isOk || result.location == null) {
      return;
    }
    final DeviceLocation gps = result.location!;

    // Cache coordinates immediately so Home/Map can use them before geocoding.
    draft.applyDevicePickup(
      MockLocation(
        id: 'gps_pickup',
        label: 'Current location',
        address: '',
        city: '',
        iconName: 'my_location',
        latitude: gps.latitude,
        longitude: gps.longitude,
      ),
    );

    final ResolvedAddress? resolved = await service.reverse(gps.point);
    final String formatted = resolved?.address.trim() ?? '';
    draft.applyDevicePickup(
      MockLocation(
        id: 'gps_pickup',
        label: formatted.isNotEmpty ? formatted : 'Current location',
        address: formatted,
        city: resolved?.city ?? '',
        iconName: 'my_location',
        latitude: gps.latitude,
        longitude: gps.longitude,
      ),
    );
  } catch (_) {
    // GPS or permission is unavailable. Callers keep rendering without it.
  } finally {
    _deviceLocationWarmInFlight = false;
  }
}

Future<void> _warmFromRef(WidgetRef ref) {
  return warmCachedDeviceLocation(
    service: ref.read(deviceLocationServiceProvider),
    draft: ref.read(bookingDraftProvider.notifier),
    readDeviceLocation: () => ref.read(bookingDraftProvider).deviceLocation,
  );
}

/// Reads the device GPS once when the customer app opens and stores it as
/// the device location. It does not replace the selected pickup.
class StartupDevicePickup extends ConsumerStatefulWidget {
  const StartupDevicePickup({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupDevicePickup> createState() => _StartupDevicePickupState();
}

class _StartupDevicePickupState extends ConsumerState<StartupDevicePickup>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmFromRef(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _warmFromRef(ref);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
