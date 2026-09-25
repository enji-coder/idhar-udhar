import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/auth_api.dart';
import 'package:idhar_udhar/shared/api/notifications_api.dart';
import 'package:idhar_udhar/shared/api/profiles_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

import 'package:intl/intl.dart';

import '../data/dummy/dummy_rider_repository.dart';
import '../data/dummy/rider_finance.dart';
import '../data/local/rider_prefs.dart';
import '../data/models/recent_activity.dart';
import '../data/models/rider_bank_details.dart';
import '../data/models/rider_earnings.dart';
import '../data/models/rider_profile.dart';
import '../data/models/vehicle_info.dart';

String riderPhoneDigits(String raw) {
  String digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length > 10) {
    digits = digits.substring(digits.length - 10);
  }
  return digits;
}

String formatRiderPhone(String raw) {
  final String digits = riderPhoneDigits(raw);
  if (digits.length != 10) return '';
  return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
}

class RiderSessionState {
  const RiderSessionState({
    this.phone = '',
    this.isAuthenticated = false,
    this.offers = const <RiderOffer>[],
    this.notices = const <ApiNotification>[],
    this.approvalStatus,
    this.onboardingKycStatus,
    this.onlineStatus,
  });

  final String phone;
  final bool isAuthenticated;
  final List<RiderOffer> offers;
  final List<ApiNotification> notices;
  final String? approvalStatus;
  final String? onboardingKycStatus;
  final String? onlineStatus;

  bool get isApproved => approvalStatus == 'APPROVED';

  RiderSessionState copyWith({
    String? phone,
    bool? isAuthenticated,
    List<RiderOffer>? offers,
    List<ApiNotification>? notices,
    String? approvalStatus,
    String? onboardingKycStatus,
    String? onlineStatus,
  }) {
    return RiderSessionState(
      phone: phone ?? this.phone,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      offers: offers ?? this.offers,
      notices: notices ?? this.notices,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      onboardingKycStatus: onboardingKycStatus ?? this.onboardingKycStatus,
      onlineStatus: onlineStatus ?? this.onlineStatus,
    );
  }

  RiderSessionState withServerProfile({
    required String? approvalStatus,
    required String? onboardingKycStatus,
    required String? onlineStatus,
    required String phone,
  }) {
    return RiderSessionState(
      phone: phone.isNotEmpty ? phone : this.phone,
      isAuthenticated: isAuthenticated,
      offers: offers,
      notices: notices,
      approvalStatus: approvalStatus,
      onboardingKycStatus: onboardingKycStatus,
      onlineStatus: onlineStatus,
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
    final OtpRequestResult result = await _auth.requestOtp(
      phone: phone,
      actor: MarketplaceActor.rider,
    );
    if (result.delivery != 'msg91') {
      throw const ApiException(
        code: 'OTP_DELIVERY_UNAVAILABLE',
        message:
            'The verification code could not be sent by SMS. Try again later.',
      );
    }
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
    _ref.read(riderProfileStateProvider.notifier).state = RiderProfile.empty;
    _ref.read(riderVehicleProvider.notifier).state = VehicleInfo.empty;
    _ref.read(riderBankProvider.notifier).state = RiderBankDetails.empty;
    _ref.read(riderDriverProvider.notifier).state = RiderDriverDetails.empty;
    state = const RiderSessionState();
  }

  Future<void> refreshProfile() async {
    try {
      _rememberProfile(await _profiles.rider());
    } catch (_) {}
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
      final DateFormat stamp = DateFormat('d MMM, h:mm a');
      return RiderEarnings(
        todayAmount: today,
        yesterdayChangePercent: 0,
        completedOrders: rows.length,
        onlineDuration: Duration.zero,
        targetOrders: rows.length,
        targetOrdersGoal: 0,
        targetAmount: today,
        targetAmountGoal: 0,
        incentiveProgress: 0,
        incentiveGoal: 0,
        recentEarnings: rows
            .map(
              (row) => RecentEarningItem(
                label: row.displayId.isEmpty ? row.orderId : row.displayId,
                amount: row.riderAmount,
                timeLabel: stamp.format(row.frozenAt.toLocal()),
              ),
            )
            .toList(growable: false),
        weeklyDeliveries: rows.length,
        weeklyEarnings: today,
        monthlyDeliveries: rows.length,
        monthlyEarnings: today,
      );
    } catch (_) {
      return RiderEarnings.empty;
    }
  }

  Future<void> refreshNotices() async {
    try {
      final notices = await _notifications.list();
      state = state.copyWith(notices: notices);
    } catch (_) {}
  }

  Future<void> _load() async {
    await refreshProfile();
    await refreshWallet();
    await refreshOffers();
    await refreshNotices();
    state = state.copyWith(isAuthenticated: true);
  }

  void _rememberProfile(RiderApiProfile profile) {
    final String rawPhone = profile.phoneNormalized ?? state.phone;
    state = state.withServerProfile(
      approvalStatus: profile.approvalStatus,
      onboardingKycStatus: profile.onboardingKycStatus,
      onlineStatus: profile.onlineStatus,
      phone: rawPhone,
    );
    final String formatted = formatRiderPhone(state.phone);
    if (formatted.isEmpty) return;
    final RiderProfile current = _ref.read(riderProfileStateProvider);
    if (current.mobile == formatted) return;
    _ref.read(riderProfileStateProvider.notifier).state =
        current.copyWith(mobile: formatted);
  }
}

final riderSessionProvider =
    StateNotifierProvider<RiderSessionNotifier, RiderSessionState>((ref) {
  return RiderSessionNotifier(ref);
});

final riderApiEarningsProvider = FutureProvider<RiderEarnings>((ref) async {
  return ref.read(riderSessionProvider.notifier).loadEarnings();
});

final riderDeliveryHistoryProvider = Provider<List<RecentActivityItem>>((ref) {
  final RiderEarnings? earnings = ref.watch(riderApiEarningsProvider).value;
  if (earnings == null) return const <RecentActivityItem>[];
  return <RecentActivityItem>[
    for (final RecentEarningItem row in earnings.recentEarnings)
      RecentActivityItem(
        orderId: row.label,
        pickup: '—',
        drop: '—',
        amount: row.amount,
        timeLabel: row.timeLabel,
      ),
  ];
});
