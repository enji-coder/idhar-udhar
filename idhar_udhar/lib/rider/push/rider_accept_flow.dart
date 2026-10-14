import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';

import '../data/dummy/dummy_rider_repository.dart';
import '../data/models/rider_order.dart';
import '../routing/rider_routes.dart';
import '../state/rider_session.dart';
import 'rider_offer_diag.dart';
import 'rider_offer_rules.dart';

/// One confirmed accept, then the order used on Order Details.
///
/// Throws [ApiException] when acceptance fails. Callers navigate only after
/// this returns.
Future<RiderOrder> loadOrderAfterAccept({
  required RiderApi api,
  required RiderOffer offer,
}) async {
  final ApiOrder accepted = await api.acceptOffer(offer.offerId);
  var details = accepted;
  final String orderId = accepted.orderId.trim();
  if (orderId.isNotEmpty) {
    try {
      details = await api.getOrder(orderId);
    } on ApiException catch (error) {
      riderOfferLog(
        'order_details_failed',
        offerId: offer.offerId,
        reason: error.code,
      );
    } catch (error) {
      riderOfferLog(
        'order_details_failed',
        offerId: offer.offerId,
        reason: error.runtimeType.toString(),
      );
    }
  }
  return OrderMapper.toRiderOrder(
    offer: acceptedOfferState(active: offer, order: details),
    order: details,
  );
}

/// Stores the accepted trip and refreshes the offer list.
///
/// Navigation stays with the caller so a dialog can close before the route
/// changes. The only success route is [RiderRoutes.orderDetails].
Future<String> publishAcceptedOrder({
  required WidgetRef ref,
  required RiderOrder order,
}) async {
  ref.read(activeOrderProvider.notifier).state = order;
  ref.read(deliveryStatusProvider.notifier).state =
      DeliveryLifecycleStatus.accepted;
  try {
    await ref.read(riderSessionProvider.notifier).refreshOffers();
  } catch (_) {
    // The accepted order is already stored. A stale offer list must not
    // block Order Details.
  }
  return RiderRoutes.orderDetails;
}
