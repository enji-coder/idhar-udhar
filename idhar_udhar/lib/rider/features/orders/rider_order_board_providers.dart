import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/local/rider_prefs.dart';
import 'rider_order_board.dart';

final riderHistoryLimitProvider = StateProvider<int>(
  (Ref ref) => riderHistoryPageSize,
);

final riderOrderHistoryProvider =
    FutureProvider<RiderHistorySnapshot>((Ref ref) async {
  final int limit = ref.watch(riderHistoryLimitProvider);
  return loadRiderOrderHistory(
    orders: (String? cursor) => ref.read(riderApiProvider).listRiderOrders(
          limit: riderHistoryPageSize,
          cursor: cursor,
        ),
    earnings: () => ref.read(walletApiProvider).earnings(),
    order: (String orderId) => ref.read(riderApiProvider).getOrder(orderId),
    paymentLabel: (String orderId) async {
      final ApiOrderPaymentView? view =
          await ref.read(riderApiProvider).getOrderPayment(orderId);
      final ApiPaymentPlan? plan = view?.plan;
      if (view == null || plan == null || !view.hasAllocation) {
        return null;
      }
      return paymentMethodLabel(
        cash: plan.customerPlannedCash + plan.receiverPlannedCash,
        online: plan.customerPlannedOnline + plan.receiverPlannedOnline,
      );
    },
    limit: limit,
  );
});

final riderWalletLedgerProvider =
    FutureProvider<List<RiderWalletLedgerEntry>>((Ref ref) async {
  final List<Map<String, Object?>> rows =
      await ref.read(walletApiProvider).walletLedger();
  return parseWalletLedger(rows);
});

final riderRunningRefreshProvider = StateProvider<int>((Ref ref) => 0);

final riderRunningDeliveriesProvider =
    FutureProvider<RiderRunningBoard>((Ref ref) async {
  ref.watch(riderRunningRefreshProvider);
  try {
    final String? remembered = await readRememberedLiveOrderId();
    final List<String> extra = <String>[];
    try {
      final List<RiderOffer> offers =
          await ref.read(riderApiProvider).listOffers();
      for (final RiderOffer offer in offers) {
        final String id = offer.orderId.trim();
        if (offer.status.toUpperCase() == 'ACCEPTED' &&
            id.isNotEmpty &&
            riderCanonicalIsRunning(offer.orderStatus ?? '')) {
          extra.add(id);
        }
      }
    } catch (_) {}
    final RiderRunningBoard board = await loadRunningDeliveries(
      local: ref.read(activeOrderProvider),
      localStatus: ref.read(deliveryStatusProvider),
      rememberedOrderId: remembered,
      extraOrderIds: extra,
      earnings: () => ref.read(walletApiProvider).earnings(),
      order: (String orderId) => ref.read(riderApiProvider).getOrder(orderId),
    );
    if (board.clearRemembered || board.clearLocalOrder) {
      await rememberLiveOrderId(null);
    }
    for (final RiderTrackedDelivery item in board.running) {
      final String id = (item.order.backendOrderId ?? '').trim();
      if (id.isNotEmpty) {
        await rememberLiveOrderId(id);
        break;
      }
    }
    return board;
  } on ApiException catch (error) {
    return RiderRunningBoard(
      running: const <RiderTrackedDelivery>[],
      clearLocalOrder: false,
      errorMessage: error.message,
    );
  } catch (_) {
    return const RiderRunningBoard(
      running: <RiderTrackedDelivery>[],
      clearLocalOrder: false,
      errorMessage: 'Active deliveries could not be loaded.',
    );
  }
});

void refreshRiderRunningDeliveries(WidgetRef ref) {
  ref.read(riderRunningRefreshProvider.notifier).state++;
}
