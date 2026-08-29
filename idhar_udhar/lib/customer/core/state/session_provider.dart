import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/auth_api.dart';
import 'package:idhar_udhar/shared/api/notifications_api.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/profiles_api.dart';
import 'package:idhar_udhar/shared/api/token_store.dart';

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
  SessionNotifier({
    SessionStorage? storage,
    AuthApi? authApi,
    OrdersApi? ordersApi,
    NotificationsApi? notificationsApi,
    ProfilesApi? profilesApi,
    TokenStore? tokenStore,
  })  : _storage = storage ?? SessionStorage(),
        _authApi = authApi,
        _ordersApi = ordersApi,
        _notificationsApi = notificationsApi,
        _profilesApi = profilesApi,
        _tokenStore = tokenStore,
        super(SessionState(orders: MockData.seedOrders()));

  final SessionStorage _storage;
  final AuthApi? _authApi;
  final OrdersApi? _ordersApi;
  final NotificationsApi? _notificationsApi;
  final ProfilesApi? _profilesApi;
  final TokenStore? _tokenStore;

  /// Returning-user names keyed by phone (demo; persisted locally).
  final Map<String, String> _knownNames = <String, String>{};

  /// Invoicing emails keyed by phone (demo; persisted locally).
  final Map<String, String> _knownEmails = <String, String>{};

  /// Restore backend session when tokens are still valid.
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

    final TokenStore? tokens = _tokenStore;
    final AuthApi? auth = _authApi;
    if (tokens == null || auth == null || !(await tokens.hasRefreshToken)) {
      state = state.copyWith(
        isHydrated: true,
        isAuthenticated: false,
        clearUser: true,
        orders: const <MockOrder>[],
      );
      return;
    }

    try {
      await auth.session();
      final String phone = (await tokens.phone) ?? '';
      await _loadAuthenticated(phone);
    } on ApiException {
      await tokens.clear();
      await _storage.clearSession();
      state = const SessionState(isHydrated: true);
    } catch (_) {
      await tokens.clear();
      await _storage.clearSession();
      state = const SessionState(isHydrated: true);
    }
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

  Future<void> requestOtp() async {
    final MockUser? user = state.user;
    final AuthApi? auth = _authApi;
    if (user == null || auth == null) {
      return;
    }
    await auth.requestOtp(
      phone: user.phone,
      actor: MarketplaceActor.customer,
    );
  }

  /// Backend OTP verify. Dummy 4-digit path remains only when APIs are absent.
  Future<bool> verifyOtp(String code) async {
    final MockUser? user = state.user;
    if (user == null) {
      return false;
    }
    final AuthApi? auth = _authApi;
    if (auth == null) {
      if (code.length != 4) {
        return false;
      }
      state = state.copyWith(isAuthenticated: true);
      unawaited(_persistAuthenticatedUser());
      return true;
    }
    await auth.verifyOtp(
      phone: user.phone,
      actor: MarketplaceActor.customer,
      code: code,
    );
    await _loadAuthenticated(user.phone);
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
    unawaited(_persistAuthenticatedUser());
    unawaited(_storage.saveKnownNames(_knownNames));
  }

  void setEmail(String email) {
    final MockUser? current = state.user;
    if (current == null) {
      return;
    }
    final String trimmed = email.trim();
    _knownEmails[current.phone] = trimmed;
    state = state.copyWith(user: current.copyWith(email: trimmed));
    unawaited(_persistAuthenticatedUser());
    unawaited(_storage.saveKnownEmails(_knownEmails));
  }

  void upsertOrder(MockOrder order) {
    final List<MockOrder> next = [
      order,
      ...state.orders.where((o) => o.apiId != order.apiId && o.id != order.id),
    ];
    state = state.copyWith(orders: next);
  }

  void updateOrder(MockOrder order) => upsertOrder(order);

  MockOrder? orderById(String id) {
    for (final MockOrder order in state.orders) {
      if (order.id == id ||
          order.backendOrderId == id ||
          order.displayId == id) {
        return order;
      }
    }
    return null;
  }

  Future<void> refreshOrders() async {
    final OrdersApi? api = _ordersApi;
    if (api == null || !state.isAuthenticated) {
      return;
    }
    final List<MockOrder> orders =
        (await api.list()).map(OrderMapper.toMockOrder).toList(growable: false);
    state = state.copyWith(orders: orders);
  }

  Future<void> refreshNotices() async {
    final NotificationsApi? api = _notificationsApi;
    if (api == null || !state.isAuthenticated) {
      return;
    }
    final notices = (await api.list())
        .map(
          (item) => CustomerNotice(
            id: item.id,
            title: item.title,
            body: item.body,
            orderId: item.orderId,
            read: item.isRead,
          ),
        )
        .toList(growable: false);
    state = state.copyWith(notices: notices);
  }

  Future<void> markNoticeRead(String id) async {
    final NotificationsApi? api = _notificationsApi;
    if (api != null) {
      await api.markRead(id);
    }
    state = state.copyWith(
      notices: state.notices
          .map(
            (CustomerNotice notice) => notice.id == id
                ? CustomerNotice(
                    id: notice.id,
                    title: notice.title,
                    body: notice.body,
                    orderId: notice.orderId,
                    read: true,
                  )
                : notice,
          )
          .toList(growable: false),
    );
  }

  Future<void> markAllNoticesRead() async {
    final NotificationsApi? api = _notificationsApi;
    if (api != null) {
      await api.markAllRead();
    }
    state = state.copyWith(
      notices: state.notices
          .map(
            (CustomerNotice notice) => CustomerNotice(
              id: notice.id,
              title: notice.title,
              body: notice.body,
              orderId: notice.orderId,
              read: true,
            ),
          )
          .toList(growable: false),
    );
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
    final AuthApi? auth = _authApi;
    if (auth != null) {
      await auth.logout();
    } else {
      await _tokenStore?.clear();
    }
    await _storage.clearSession();
    state = SessionState(isHydrated: true);
  }

  Future<void> _loadAuthenticated(String phone) async {
    String name = _knownNames[phone] ?? _knownNames['+91$phone'] ?? '';
    String email = _knownEmails[phone] ?? _knownEmails['+91$phone'] ?? '';
    String id = 'u_${phone.hashCode.abs()}';
    try {
      final ProfilesApi? profiles = _profilesApi;
      if (profiles != null) {
        final profile = await profiles.customer();
        id = profile.customerProfileId;
        final String? remoteName = profile.displayName?.trim();
        if (remoteName != null && remoteName.isNotEmpty) {
          name = remoteName;
        }
        final String? remoteEmail =
            (profile.invoiceEmail ?? profile.email)?.trim();
        if (remoteEmail != null && remoteEmail.isNotEmpty) {
          email = remoteEmail;
        }
      }
    } catch (_) {
      // Local name overlay still applies when profile GET fails.
    }
    final MockUser user = MockUser(
      id: id,
      phone: phone.startsWith('+') ? phone : '+91$phone',
      name: name,
      email: email,
    );
    List<MockOrder> orders = const <MockOrder>[];
    try {
      final OrdersApi? api = _ordersApi;
      if (api != null) {
        orders = (await api.list())
            .map(OrderMapper.toMockOrder)
            .toList(growable: false);
      }
    } catch (_) {
      orders = const <MockOrder>[];
    }
    List<CustomerNotice> notices = const <CustomerNotice>[];
    try {
      final NotificationsApi? api = _notificationsApi;
      if (api != null) {
        notices = (await api.list())
            .map(
              (item) => CustomerNotice(
                id: item.id,
                title: item.title,
                body: item.body,
                orderId: item.orderId,
                read: item.isRead,
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {
      notices = const <CustomerNotice>[];
    }
    state = SessionState(
      user: user,
      isAuthenticated: true,
      walletBalance: 420,
      orders: orders,
      isHydrated: true,
      notices: notices,
    );
    unawaited(_persistAuthenticatedUser());
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
  return SessionNotifier(
    authApi: ref.watch(authApiProvider),
    ordersApi: ref.watch(ordersApiProvider),
    notificationsApi: ref.watch(notificationsApiProvider),
    profilesApi: ref.watch(profilesApiProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});
