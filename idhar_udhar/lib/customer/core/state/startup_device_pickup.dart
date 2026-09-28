import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';

import '../data/mock/mock_models.dart';
import 'booking_draft_provider.dart';

/// Reads the device location once when the customer app opens and, unless the
/// customer has already chosen a pickup, stores it on the booking draft.
class StartupDevicePickup extends ConsumerStatefulWidget {
  const StartupDevicePickup({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupDevicePickup> createState() => _StartupDevicePickupState();
}

class _StartupDevicePickupState extends ConsumerState<StartupDevicePickup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    try {
      final DeviceLocationService service =
          ref.read(deviceLocationServiceProvider);
      final LocationResult result = await service.currentLocation();
      if (!mounted || !result.isOk || result.location == null) {
        return;
      }
      final DeviceLocation gps = result.location!;
      final ResolvedAddress? resolved = await service.reverse(gps.point);
      if (!mounted) {
        return;
      }
      final String formatted = resolved?.address.trim() ?? '';
      ref.read(bookingDraftProvider.notifier).applyDevicePickup(
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
      // GPS or permission is unavailable. The existing pickup seed stays.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
