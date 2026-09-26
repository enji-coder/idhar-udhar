import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/recent_locations_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recent searches start empty and store only a real selection', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final RecentLocationsNotifier notifier = RecentLocationsNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, isEmpty);

    await notifier.remember(
      const MockLocation(
        id: 'place_1',
        label: 'Gate',
        address: 'Real street 4',
      ),
    );
    expect(notifier.state.map((MockLocation loc) => loc.address), <String>[
      'Real street 4',
    ]);
  });

  test('deleting one recent search leaves the others', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final RecentLocationsNotifier notifier = RecentLocationsNotifier();
    await Future<void>.delayed(Duration.zero);
    await notifier.remember(
      const MockLocation(
        id: 'place_1',
        label: 'Shilaj',
        address: 'Shilaj, Ahmedabad',
        latitude: 23.04,
        longitude: 72.48,
      ),
    );
    await notifier.remember(
      const MockLocation(
        id: 'place_2',
        label: 'Satellite',
        address: 'Satellite, Ahmedabad',
        latitude: 23.03,
        longitude: 72.52,
      ),
    );
    await notifier.forget('place_1');
    expect(notifier.state.map((MockLocation loc) => loc.id), <String>['place_2']);
    expect(notifier.state.single.latitude, 23.03);
  });
}
