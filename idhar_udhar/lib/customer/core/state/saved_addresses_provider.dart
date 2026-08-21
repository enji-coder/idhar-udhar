import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_constants.dart';
import '../data/mock/mock_data.dart';
import '../data/mock/mock_models.dart';

class SavedAddressesState {
  const SavedAddressesState({
    this.addresses = const <MockLocation>[],
    this.isLoading = false,
    this.error,
  });

  final List<MockLocation> addresses;
  final bool isLoading;
  final String? error;

  bool get isEmpty => addresses.isEmpty;

  SavedAddressesState copyWith({
    List<MockLocation>? addresses,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SavedAddressesState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SavedAddressesNotifier extends StateNotifier<SavedAddressesState> {
  SavedAddressesNotifier() : super(const SavedAddressesState(isLoading: true)) {
    // ignore: discarded_futures
    load();
  }

  static const String _key = '${AppConstants.prefsPrefix}saved_addresses_v1';

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        final List<MockLocation> seeded = MockData.locations
            .where((l) => l.isSaved)
            .toList(growable: false);
        await _persist(seeded);
        state = SavedAddressesState(addresses: seeded);
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        state = const SavedAddressesState(
          error: 'Could not load saved addresses.',
        );
        return;
      }
      final List<MockLocation> items = decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> e) =>
                MockLocation.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.id.isNotEmpty && e.address.trim().isNotEmpty)
          .toList();
      state = SavedAddressesState(addresses: items);
    } catch (_) {
      state = const SavedAddressesState(
        error: 'Could not load saved addresses.',
      );
    }
  }

  Future<void> add(MockLocation location) async {
    final List<MockLocation> next = <MockLocation>[
      location,
      ...state.addresses.where((a) => a.id != location.id),
    ];
    await _persist(next);
    state = SavedAddressesState(addresses: next);
  }

  Future<void> update(MockLocation location) async {
    final List<MockLocation> next = state.addresses
        .map((a) => a.id == location.id ? location : a)
        .toList();
    await _persist(next);
    state = SavedAddressesState(addresses: next);
  }

  Future<void> delete(String id) async {
    final List<MockLocation> next =
        state.addresses.where((a) => a.id != id).toList();
    await _persist(next);
    state = SavedAddressesState(addresses: next);
  }

  Future<void> _persist(List<MockLocation> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}

final savedAddressesProvider =
    StateNotifierProvider<SavedAddressesNotifier, SavedAddressesState>((ref) {
  return SavedAddressesNotifier();
});
