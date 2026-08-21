import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_data.dart';
import '../data/mock/mock_models.dart';
import '../storage/session_storage.dart';

class SessionState {
  const SessionState({
    this.user,
    this.isAuthenticated = false,
    this.walletBalance = 420,
    this.orders = const [],
    this.isHydrated = false,
    this.notices = const [],
  });

  final MockUser? user;
  final bool isAuthenticated;
  final double walletBalance;
  final List<MockOrder> orders;

  /// True after local session restore has finished (success or empty).
  final bool isHydrated;
  final List<CustomerNotice> notices;

  SessionState copyWith({
    MockUser? user,
    bool? isAuthenticated,
    double? walletBalance,
    List<MockOrder>? orders,
    bool? isHydrated,
    bool clearUser = false,
    List<CustomerNotice>? notices,
  }) {
    return SessionState(
      user: clearUser ? null : (user ?? this.user),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      walletBalance: walletBalance ?? this.walletBalance,
      orders: orders ?? this.orders,
      isHydrated: isHydrated ?? this.isHydrated,
      notices: notices ?? this.notices,
    );
  }
}

class CustomerNotice {
  const CustomerNotice({
    required this.id,
    required this.title,
    required this.body,
    this.orderId,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String? orderId;
  final bool read;
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier({SessionStorage? storage})
      : _storage = storage ?? SessionStorage(),
        super(SessionState(orders: MockData.seedOrders()));

  final SessionStorage _storage;

  /// Returning-user names keyed by phone (demo; persisted locally).
  final Map<String, String> _knownNames = <String, String>{};

  /// Invoicing emails keyed by phone (demo; persisted locally).
  final Map<String, String> _knownEmails = <String, String>{};

  /// Restore persisted login before first navigation decision.
  Future<void> hydrate() async {
    if (state.isHydrated) {
      return;
    }

    final Map<String, String> names = await _storage.loadKnownNames();
    final Map<String, String> emails = await _storage.loadKnownEmails();
    _knownNames
      ..clear()
      ..addAll(names);
    _knownEmails
      ..clear()
      ..addAll(emails);

    final PersistedSession? saved = await _storage.loadSession();
    if (saved != null) {
      state = SessionState(
        user: saved.user,
        isAuthenticated: true,
        walletBalance: 420,
        orders: MockData.seedOrders(),
        isHydrated: true,
      );
      return;
    }

    state = state.copyWith(isHydrated: true);
  }

  void startLogin(String phone) {
    final String normalized = phone.startsWith('+') ? phone : '+91$phone';
    state = state.copyWith(
      user: MockUser(
        id: 'u_${normalized.hashCode.abs()}',
        phone: normalized,
        name: _knownNames[normalized] ?? '',
        email: _knownEmails[normalized] ?? '',
      ),
      isAuthenticated: false,
    );
  }

  /// Dummy OTP verify — any 4-digit code accepted for UI demo.
  bool verifyOtp(String code) {
    if (code.length != 4 || state.user == null) {
      return false;
    }
    state = state.copyWith(isAuthenticated: true);
    // Persist immediately so kill/reopen keeps the session.
    // ignore: discarded_futures
    _persistAuthenticatedUser();
    return true;
  }

  bool get needsProfileSetup =>
      state.isAuthenticated && !(state.user?.hasName ?? false);

  void setName(String name) {
    final MockUser? current = state.user;
    if (current == null) {
      return;
    }
    final String trimmed = name.trim();
    _knownNames[current.phone] = trimmed;
    state = state.copyWith(user: current.copyWith(name: trimmed));
    // ignore: discarded_futures
    _persistAuthenticatedUser();
    // ignore: discarded_futures
    _storage.saveKnownNames(_knownNames);
  }

  void setEmail(String email) {
    final MockUser? current = state.user;
    if (current == null) {
      return;
    }
    final String trimmed = email.trim();
    _knownEmails[current.phone] = trimmed;
    state = state.copyWith(user: current.copyWith(email: trimmed));
    // ignore: discarded_futures
    _persistAuthenticatedUser();
    // ignore: discarded_futures
    _storage.saveKnownEmails(_knownEmails);
  }

  void upsertOrder(MockOrder order) {
    final List<MockOrder> next = [
      order,
      ...state.orders.where((o) => o.id != order.id),
    ];
    state = state.copyWith(orders: next);
  }

  void updateOrder(MockOrder order) => upsertOrder(order);

  MockOrder? orderById(String id) {
    for (final MockOrder order in state.orders) {
      if (order.id == id) {
        return order;
      }
    }
    return null;
  }

  void addNotice(CustomerNotice notice) {
    state = state.copyWith(notices: [notice, ...state.notices]);
  }

  int get unreadNoticeCount =>
      state.notices.where((n) => !n.read).length;

  void addWallet(double amount) {
    state = state.copyWith(walletBalance: state.walletBalance + amount);
  }

  Future<void> logout() async {
    await _storage.clearSession();
    state = SessionState(
      orders: MockData.seedOrders(),
      isHydrated: true,
    );
  }

  Future<void> _persistAuthenticatedUser() async {
    final MockUser? user = state.user;
    if (!state.isAuthenticated || user == null) {
      return;
    }
    await _storage.saveSession(user);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
