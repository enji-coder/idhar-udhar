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

  test('maps assigned rider display fields without inventing rating', () {
    final MockOrder order = OrderMapper.toMockOrder(
      ApiOrder(
        orderId: '11111111-1111-1111-1111-111111111111',
        displayId: 'IU-AMD-0002',
        canonicalStatus: 'ASSIGNED',
        createdAt: DateTime.utc(2026, 1, 1),
        riderProfileId: '22222222-2222-4222-8222-222222222222',
        vehicleCategoryName: 'Bike',
        assignedRider: const ApiAssignedRider(
          name: 'Ravi',
          vehicleRegistration: 'GJ-01-AB-1234',
          vehicleCategoryName: 'Bike',
        ),
        tripFare: 120,
      ),
    );
    expect(order.status, OrderStatus.assigned);
    expect(order.rider, isNotNull);
    expect(order.rider!.name, 'Ravi');
    expect(order.rider!.vehicleLabel, contains('Bike'));
    expect(order.rider!.vehicleLabel, contains('GJ-01-AB-1234'));
    expect(order.rider!.rating, 0);
    expect(order.vehicle.name, 'Bike');
    expect(order.vehicle.imagePath, isNotEmpty);
  });

  test('cancelled history amount is zero and CRN is copied, not recomputed', () {
    final MockOrder order = OrderMapper.toMockOrder(
      ApiOrder(
        orderId: '11111111-1111-1111-1111-111111111111',
        displayId: 'IU-AMD-0000000003',
        crn: 'IU-CRN-AMD-0000000003',
        canonicalStatus: 'CANCELLED',
        createdAt: DateTime.utc(2026, 1, 1),
        tripFare: 250,
        netPayable: 250,
        vehicleCategoryName: 'Truck',
      ),
    );
    expect(order.fare, 0);
    expect(order.tripFare, 250);
    expect(order.crn, 'IU-CRN-AMD-0000000003');
    expect(order.vehicle.imagePath, contains('truck'));
  });
}
