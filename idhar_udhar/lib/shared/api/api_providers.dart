import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_api.dart';
import 'notifications_api.dart';
import 'orders_api.dart';
import 'profiles_api.dart';
import 'rider_api.dart';
import 'token_store.dart';
import 'wallet_api.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final TokenStore store = ref.watch(tokenStoreProvider);
  return ApiClient(tokenStore: store);
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider));
});

final profilesApiProvider = Provider<ProfilesApi>((ref) {
  return ProfilesApi(ref.watch(apiClientProvider));
});

final ordersApiProvider = Provider<OrdersApi>((ref) {
  return OrdersApi(ref.watch(apiClientProvider));
});

final riderApiProvider = Provider<RiderApi>((ref) {
  return RiderApi(ref.watch(apiClientProvider));
});

final walletApiProvider = Provider<WalletApi>((ref) {
  return WalletApi(ref.watch(apiClientProvider));
});

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.watch(apiClientProvider));
});
