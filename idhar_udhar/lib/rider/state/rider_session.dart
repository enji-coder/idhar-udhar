import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/auth_api.dart';
import 'package:idhar_udhar/shared/api/notifications_api.dart';
import 'package:idhar_udhar/shared/api/profiles_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

import '../data/dummy/dummy_rider_data.dart';
import '../data/dummy/dummy_rider_repository.dart';
import '../data/dummy/rider_finance.dart';
import '../data/local/rider_prefs.dart';
import '../data/models/rider_earnings.dart';

class RiderSessionState {
  const RiderSessionState({
    this.phone = '',
    this.isAuthenticated = false,
    this.offers = const <RiderOffer>[],
    this.notices = const <ApiNotification>[],
  });

  final String phone;
  final bool isAuthenticated;
  final List<RiderOffer> offers;
  final List<ApiNotification> notices;

  RiderSessionState copyWith({
    String? phone,
    bool? isAuthenticated,
    List<RiderOffer>? offers,
    List<ApiNotification>? notices,
  }) {
    return RiderSessionState(
      phone: phone ?? this.phone,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      offers: offers ?? this.offers,
      notices: notices ?? this.notices,
    );
  }
}

class RiderSessionNotifier extends StateNotifier<RiderSessionState> {
  RiderSessionNotifier(this._ref) : super(const RiderSessionState());

  final Ref _ref;

  AuthApi get _auth => _ref.read(authApiProvider);
  RiderApi get _rider => _ref.read(riderApiProvider);
  WalletApi get _wallet => _ref.read(walletApiProvider);
  NotificationsApi get _notifications => _ref.read(notificationsApiProvider);
  ProfilesApi get _profiles => _ref.read(profilesApiProvider);

  Future<bool> restore() async {
    if (!await _ref.read(tokenStoreProvider).hasRefreshToken) {
      state = const RiderSessionState();
      return false;
    }
    try {
      await _auth.session();
      await _load();
      await RiderPrefs.setLoggedIn();
      return true;
    } catch (_) {
      await _ref.read(tokenStoreProvider).clear();
      await RiderPrefs.clearLoggedIn();
      state = const RiderSessionState();
      return false;
    }
  }

  Future<void> requestOtp(String phone) async {
    state = state.copyWith(phone: phone);
    await _auth.requestOtp(phone: phone, actor: MarketplaceActor.rider);
  }

  void bindPhone(String phone) {
    state = state.copyWith(phone: phone);
  }

  Future<void> verifyOtp(String code) async {
    await _auth.verifyOtp(
      phone: state.phone,
      actor: MarketplaceActor.rider,
      code: code,
    );
    await _load();
    await RiderPrefs.setLoggedIn();
  }

  Future<void> logout() async {
    await _auth.logout();
    await RiderPrefs.clearLoggedIn();
    state = const RiderSessionState();
  }

  Future<void> refreshOffers() async {
    try {
      final List<RiderOffer> offers = await _rider.listOffers();
      state = state.copyWith(offers: offers);
    } on ApiException {
      state = state.copyWith(offers: const <RiderOffer>[]);
    }
  }

  Future<void> refreshWallet() async {
    try {
      final wallet = await _wallet.wallet();
      final cod = await _wallet.cod();
      _ref.read(riderWalletBalanceProvider.notifier).state =
          wallet.availableBalance;
      _ref.read(riderCodDueProvider.notifier).state = cod.codDue;
    } catch (_) {
      // Keep last displayed values if the request fails.
    }
  }

  Future<RiderEarnings> loadEarnings() async {
    try {
      final rows = await _wallet.earnings();
      final double today = rows.fold<double>(
        0,
        (double sum, row) => sum + row.riderAmount,
      );
      return RiderEarnings(
        todayAmount: today,
        yesterdayChangePercent: DummyRiderData.earnings.yesterdayChangePercent,
        completedOrders: rows.length,
        onlineDuration: DummyRiderData.earnings.onlineDuration,
        targetOrders: DummyRiderData.earnings.targetOrders,
        targetOrdersGoal: DummyRiderData.earnings.targetOrdersGoal,
        targetAmount: today,
        targetAmountGoal: DummyRiderData.earnings.targetAmountGoal,
        incentiveProgress: DummyRiderData.earnings.incentiveProgress,
        incentiveGoal: DummyRiderData.earnings.incentiveGoal,
        recentEarnings: rows
            .take(5)
            .map(
              (row) => RecentEarningItem(
                label: row.displayId,
                amount: row.riderAmount,
                timeLabel: '',
              ),
            )
            .toList(growable: false),
        weeklyDeliveries: rows.length,
        weeklyEarnings: today,
        monthlyDeliveries: rows.length,
        monthlyEarnings: today,
      );
    } catch (_) {
      return DummyRiderData.earnings;
    }
  }

  Future<void> refreshNotices() async {
    try {
      final notices = await _notifications.list();
      state = state.copyWith(notices: notices);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      await _profiles.rider();
    } catch (_) {}
    await refreshWallet();
    await refreshOffers();
    await refreshNotices();
    state = state.copyWith(isAuthenticated: true);
  }
}

final riderSessionProvider =
    StateNotifierProvider<RiderSessionNotifier, RiderSessionState>((ref) {
  return RiderSessionNotifier(ref);
});

final riderApiEarningsProvider = FutureProvider<RiderEarnings>((ref) async {
  return ref.read(riderSessionProvider.notifier).loadEarnings();
});
