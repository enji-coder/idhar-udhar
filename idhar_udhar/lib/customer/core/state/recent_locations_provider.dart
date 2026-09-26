import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_constants.dart';
import '../data/mock/mock_models.dart';

class RecentLocationsNotifier extends StateNotifier<List<MockLocation>> {
  RecentLocationsNotifier() : super(const <MockLocation>[]) {
    // ignore: discarded_futures
    load();
  }

  static const String _key = '${AppConstants.prefsPrefix}recent_locations_v1';
  static const int _max = 8;

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        state = const <MockLocation>[];
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        state = const <MockLocation>[];
        return;
      }
      state = decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> e) =>
                MockLocation.fromJson(Map<String, dynamic>.from(e)),
          )
          .where(
            (MockLocation loc) =>
                loc.id.isNotEmpty && loc.address.trim().isNotEmpty,
          )
          .take(_max)
          .toList(growable: false);
    } catch (_) {
      state = const <MockLocation>[];
    }
  }

  Future<void> remember(MockLocation location) async {
    final String address = location.address.trim();
    if (location.id.isEmpty || address.isEmpty) {
      return;
    }
    final List<MockLocation> next = <MockLocation>[
      location,
      ...state.where((MockLocation item) => item.id != location.id),
    ].take(_max).toList(growable: false);
    state = next;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((MockLocation e) => e.toJson()).toList()),
    );
  }

  Future<void> forget(String id) async {
    final String target = id.trim();
    if (target.isEmpty) {
      return;
    }
    final List<MockLocation> next = state
        .where((MockLocation item) => item.id != target)
        .toList(growable: false);
    state = next;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((MockLocation e) => e.toJson()).toList()),
    );
  }
}

final recentLocationsProvider =
    StateNotifierProvider<RecentLocationsNotifier, List<MockLocation>>((ref) {
  return RecentLocationsNotifier();
});
