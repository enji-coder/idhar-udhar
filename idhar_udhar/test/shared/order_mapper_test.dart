import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';

void main() {
  test('maps backend statuses onto existing customer UI statuses', () {
    expect(OrderMapper.toUiStatus('SEARCHING'), OrderStatus.searching);
    expect(OrderMapper.toUiStatus('ASSIGNED'), OrderStatus.assigned);
    expect(OrderMapper.toUiStatus('DELIVERED'), OrderStatus.delivered);
    expect(OrderMapper.toUiStatus('PARCEL_AT_COMPANY_OFFICE'),
        OrderStatus.atCompanyOffice,);
  });

  test('chains rider UI delivered tap onto legal backend hops', () {
    expect(
      OrderMapper.riderStatusHops(
        from: DeliveryLifecycleStatus.goingToDrop,
        to: DeliveryLifecycleStatus.delivered,
      ),
      <String>['NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED'],
    );
  });

  test('maps API order display id for existing list tiles', () {
    final MockOrder order = OrderMapper.toMockOrder(
      ApiOrder(
        orderId: '11111111-1111-1111-1111-111111111111',
        displayId: 'IU-AMD-0001',
        canonicalStatus: 'SEARCHING',
        createdAt: DateTime.utc(2026, 1, 1),
        tripFare: 79,
      ),
    );
    expect(order.displayLabel, 'IU-AMD-0001');
    expect(order.apiId, '11111111-1111-1111-1111-111111111111');
    expect(order.fare, 79);
  });
}
