import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

class CustomerWalletState {
  const CustomerWalletState({
    this.balance,
    this.entries = const <CustomerWalletEntry>[],
    this.loading = false,
    this.error,
  });

  final double? balance;
  final List<CustomerWalletEntry> entries;
  final bool loading;
  final String? error;

  bool get hasBalance => balance != null && error == null && !loading;
}

class CustomerWalletNotifier extends StateNotifier<CustomerWalletState> {
  CustomerWalletNotifier(this._api) : super(const CustomerWalletState());

  final WalletApi _api;

  Future<void> load() async {
    state = const CustomerWalletState(loading: true);
    try {
      final RiderWallet wallet = await _api.customerWallet();
      final List<CustomerWalletEntry> entries = await _api.customerLedger();
      state = CustomerWalletState(
        balance: wallet.availableBalance,
        entries: entries,
      );
    } on ApiException catch (error) {
      state = CustomerWalletState(error: error.message);
    } catch (_) {
      state = const CustomerWalletState(
        error: 'Could not load wallet. Try again.',
      );
    }
  }
}

final customerWalletProvider =
    StateNotifierProvider<CustomerWalletNotifier, CustomerWalletState>((ref) {
  return CustomerWalletNotifier(ref.watch(walletApiProvider));
});
