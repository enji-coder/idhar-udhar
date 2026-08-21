import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/booking_draft_provider.dart';
import 'package:idhar_udhar/shared/business/business.dart';

void main() {
  late ProviderContainer container;
  late BookingDraftNotifier notifier;

  MockLocation loc(String id) =>
      MockData.locations.firstWhere((l) => l.id == id);

  setUp(() {
    OrderIds.resetDemoSequence(1);
    container = ProviderContainer();
    notifier = container.read(bookingDraftProvider.notifier);
  });

  tearDown(() => container.dispose());

  BookingDraft draft() => container.read(bookingDraftProvider);

  test('each drop index is stored independently', () {
    notifier.setDeliveryMode(DeliveryMode.multiple);
    notifier.setDropCount(3);
    notifier.setDropAt(0, loc('loc_paldi'));
    notifier.setDropAt(1, loc('loc_bopal'));
    notifier.setDropAt(2, loc('loc_office'));

    expect(draft().dropAt(0)?.id, 'loc_paldi');
    expect(draft().dropAt(1)?.id, 'loc_bopal');
    expect(draft().dropAt(2)?.id, 'loc_office');
    expect(draft().allDrops.map((d) => d.id), [
      'loc_paldi',
      'loc_bopal',
      'loc_office',
    ]);
  });

  test('switching 3 drops to 2 does not submit drop 3', () {
    notifier.setDeliveryMode(DeliveryMode.multiple);
    notifier.setDropCount(3);
    notifier.setDropAt(0, loc('loc_paldi'));
    notifier.setDropAt(1, loc('loc_bopal'));
    notifier.setDropAt(2, loc('loc_office'));
    notifier.setDropCount(2);

    expect(draft().dropCount, 2);
    expect(draft().dropAt(2), isNull);
    expect(draft().allDrops.map((d) => d.id), ['loc_paldi', 'loc_bopal']);

    final MockOrder? order = notifier.confirmBooking();
    expect(order, isNotNull);
    expect(order!.extraDrops.map((d) => d.id), ['loc_bopal']);
  });

  test('confirm is blocked until every required drop is selected', () {
    notifier.setDeliveryMode(DeliveryMode.multiple);
    notifier.setDropCount(2);
    notifier.setDropAt(0, loc('loc_paldi'));

    expect(draft().incompleteStopMessage, 'Select Drop Location 2');
    expect(notifier.confirmBooking(), isNull);

    notifier.setDropCount(3);
    notifier.setDropAt(1, loc('loc_bopal'));
    expect(draft().incompleteStopMessage, 'Select Drop Location 3');
    expect(notifier.confirmBooking(), isNull);

    notifier.setDropAt(2, loc('loc_office'));
    expect(draft().incompleteStopMessage, isNull);
    expect(notifier.confirmBooking(), isNotNull);
  });

  test('second order is a new id and does not mutate the first', () {
    notifier.setDrop(loc('loc_paldi'));
    final MockOrder? first = notifier.confirmBooking();
    expect(first, isNotNull);

    notifier.beginNewBooking();
    notifier.setDrop(loc('loc_bopal'));
    final MockOrder? second = notifier.confirmBooking();

    expect(second, isNotNull);
    expect(second!.id, isNot(first!.id));
    expect(first.drop.id, 'loc_paldi');
    expect(second.drop.id, 'loc_bopal');
  });

  test('confirming the same draft twice is idempotent', () {
    notifier.setDrop(loc('loc_paldi'));
    final MockOrder? first = notifier.confirmBooking();
    final MockOrder? second = notifier.confirmBooking();
    expect(first!.id, second!.id);
  });

  test('advancing order A does not rewrite order B in the draft', () {
    notifier.setDrop(loc('loc_paldi'));
    final MockOrder a = notifier.confirmBooking()!;
    notifier.assignRider();
    final MockOrder assignedA = draft().activeOrder!;
    expect(assignedA.id, a.id);
    expect(assignedA.status, OrderStatus.assigned);

    notifier.beginNewBooking();
    notifier.setDrop(loc('loc_bopal'));
    final MockOrder b = notifier.confirmBooking()!;
    expect(draft().activeOrder?.id, b.id);
    expect(draft().activeOrder?.status, OrderStatus.searching);

    final MockOrder? updatedA = notifier.advanceDemoStatus(order: assignedA);
    expect(updatedA!.id, a.id);
    expect(updatedA.status, OrderStatus.accepted);
    expect(draft().activeOrder?.id, b.id);
    expect(draft().activeOrder?.status, OrderStatus.searching);
  });
}
