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
    this.walletBalance = 0,
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

  /// Loopback capture only. Never persisted. Null in release / live hosts.
  String? debugCapturedOtp;

  /// Returning-user names keyed by phone (demo; persisted locally).
  final Map<String, String> _knownNames = <String, String>{};

  /// Invoicing emails keyed by phone (demo; persisted locally).
  final Map<String, String> _knownEmails = <String, String>{};

  /// Invalidates in-flight hydrate work so a late API result cannot
  /// re-authenticate after timeout/fallback.
  int _hydrateEpoch = 0;

  /// Restore backend session when tokens are still valid.
  ///
  /// Always finishes: unauthenticated, authenticated, or timeout/error
  /// fallback. Splash must never wait on this indefinitely.
  Future<void> hydrate({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (state.isHydrated) {
      return;
    }
    final int epoch = ++_hydrateEpoch;
    try {
      await _restoreSession(epoch).timeout(timeout);
    } on TimeoutException {
      _finishHydrateUnauthenticated(epoch);
    } catch (_) {
      _finishHydrateUnauthenticated(epoch);
    }
  }

  Future<void> _restoreSession(int epoch) async {
    final Map<String, String> names = await _storage.loadKnownNames();
    final Map<String, String> emails = await _storage.loadKnownEmails();
    if (!_hydrateActive(epoch)) {
      return;
    }
    _knownNames
      ..clear()
      ..addAll(names);
    _knownEmails
      ..clear()
      ..addAll(emails);

    final TokenStore? tokens = _tokenStore;
    final AuthApi? auth = _authApi;
    if (tokens == null || auth == null || !(await tokens.hasRefreshToken)) {
      _finishHydrateUnauthenticated(epoch);
      return;
    }

    try {
      await auth.session();
      if (!_hydrateActive(epoch)) {
        return;
      }
      final String phone = (await tokens.phone) ?? '';
      await _loadAuthenticated(phone, loadFeeds: false, hydrateEpoch: epoch);
    } on ApiException catch (error) {
      if (!_hydrateActive(epoch)) {
        return;
      }
      if (error.isUnauthenticated) {
        await tokens.clear();
        await _storage.clearSession();
      }
      _finishHydrateUnauthenticated(epoch);
    } catch (_) {
      _finishHydrateUnauthenticated(epoch);
    }
  }

  bool _hydrateActive(int epoch) =>
      epoch == _hydrateEpoch && !state.isHydrated;

  void _finishHydrateUnauthenticated(int epoch) {
    if (!_hydrateActive(epoch)) {
      return;
    }
    _hydrateEpoch++;
    state = const SessionState(isHydrated: true);
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
    final OtpRequestResult result = await auth.requestOtp(
      phone: user.phone,
      actor: MarketplaceActor.customer,
    );
    debugCapturedOtp = null;
    if (result.delivery == 'capture') {
      debugCapturedOtp = await auth.peekCapturedOtp(user.phone);
    }
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
    await _loadAuthenticated(user.phone, loadFeeds: true);
    return true;
  }

  bool get needsProfileSetup {
    if (!state.isAuthenticated) {
      return false;
    }
    final String name = state.user?.name.trim() ?? '';
    return name.isEmpty || name == 'Customer';
  }

  Future<void> persistProfile({
    required String name,
    String? email,
  }) async {
    final MockUser? current = state.user;
    if (current == null) {
      return;
    }
    final String trimmed = name.trim();
    final String? trimmedEmail = email?.trim();
    final ProfilesApi? profiles = _profilesApi;
    if (profiles != null) {
      final CustomerProfile updated = await profiles.updateCustomer(
        displayName: trimmed,
        email: trimmedEmail,
      );
      final String savedName = updated.displayName?.trim().isNotEmpty == true
          ? updated.displayName!.trim()
          : trimmed;
      final String savedEmail =
          (updated.invoiceEmail ?? updated.email)?.trim() ??
              trimmedEmail ??
              current.email;
      _knownNames[current.phone] = savedName;
      if (savedEmail.isNotEmpty) {
        _knownEmails[current.phone] = savedEmail;
      }
      state = state.copyWith(
        user: current.copyWith(name: savedName, email: savedEmail),
      );
    } else {
      _knownNames[current.phone] = trimmed;
      if (trimmedEmail != null) {
        _knownEmails[current.phone] = trimmedEmail;
      }
      state = state.copyWith(
        user: current.copyWith(
          name: trimmed,
          email: trimmedEmail ?? current.email,
        ),
      );
    }
    unawaited(_persistAuthenticatedUser());
    unawaited(_storage.saveKnownNames(_knownNames));
    unawaited(_storage.saveKnownEmails(_knownEmails));
  }

  void setName(String name) {
    unawaited(persistProfile(name: name));
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
    debugCapturedOtp = null;
    state = SessionState(isHydrated: true);
  }

  Future<void> _loadAuthenticated(
    String phone, {
    required bool loadFeeds,
    int? hydrateEpoch,
  }) async {
    String name = _knownNames[phone] ?? _knownNames['+91$phone'] ?? '';
    String email = _knownEmails[phone] ?? _knownEmails['+91$phone'] ?? '';
    String id = 'u_${phone.hashCode.abs()}';
    try {
      final ProfilesApi? profiles = _profilesApi;
      if (profiles != null) {
        final profile = await profiles.customer();
        id = profile.customerProfileId;
        if (profile.needsProfileSetup) {
          name = '';
        } else {
          final String? remoteName = profile.displayName?.trim();
          if (remoteName != null && remoteName.isNotEmpty) {
            name = remoteName;
          }
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
    if (hydrateEpoch != null && !_hydrateActive(hydrateEpoch)) {
      return;
    }
    final MockUser user = MockUser(
      id: id,
      phone: phone.startsWith('+') ? phone : '+91$phone',
      name: name,
      email: email,
    );
    List<MockOrder> orders = const <MockOrder>[];
    List<CustomerNotice> notices = const <CustomerNotice>[];
    if (loadFeeds) {
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
    }
    if (hydrateEpoch != null && !_hydrateActive(hydrateEpoch)) {
      return;
    }
    state = SessionState(
      user: user,
      isAuthenticated: true,
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
