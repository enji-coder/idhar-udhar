import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/state/saved_addresses_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty storage does not seed catalog addresses', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SavedAddressesNotifier notifier = SavedAddressesNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.addresses, isEmpty);
    expect(notifier.state.error, isNull);
  });

  test('previously seeded catalog rows are dropped', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'iu_saved_addresses_v1': jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'loc_home',
          'label': 'Home',
          'address': '12, Satellite Road, Ahmedabad',
        },
        <String, Object>{
          'id': 'loc_user_1',
          'label': 'Home',
          'address': 'Real street 1',
        },
      ]),
    });
    final SavedAddressesNotifier notifier = SavedAddressesNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.addresses.map((a) => a.id), <String>['loc_user_1']);
  });
}
