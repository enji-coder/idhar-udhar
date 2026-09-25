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
}
