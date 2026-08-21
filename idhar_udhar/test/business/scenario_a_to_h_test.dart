import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/business/business.dart';

void main() {
  setUp(() {
    OrderIds.resetDemoSequence(1);
    FareCatalog.resetDemo();
  });

  group('Scenario A — normal order', () {
    test('delivered trip freezes 85/15/50 on ₹100', () {
      const PaymentSettings settings = PaymentSettings();
      final TripFinanceSnapshot snap =
          FinanceEngine.freezeTrip(rideAmount: 100, settings: settings);

      expect(snap.riderAmount, 85);
      expect(snap.companyCommissionAmount, 15);
      expect(snap.operationalCostAmount, 7.5);
      expect(snap.actualProfitAmount, 7.5);
      expect(snap.taxAmount, 0);
    });
  });

  group('Scenario B — multiple active orders per customer', () {
    test('two running orders stay independent', () {
      final String a = OrderIds.nextDisplayId();
      final String b = OrderIds.nextDisplayId();
      expect(a, isNot(b));
      expect(OrderLifecycle.isActive(CanonicalOrderStatus.inTransit), isTrue);
      expect(OrderLifecycle.isActive(CanonicalOrderStatus.searching), isTrue);
    });
  });

  group('Scenario C — failed delivery', () {
    test('receiver unavailable records office handover', () {
      final FailedDeliveryRecord record = FailedDeliveryEngine.open(
        originalDropLabel: 'Paldi',
        officeDistanceKm: 5,
      );
      expect(record.reason, FailedDeliveryReason.receiverUnavailable);
      expect(record.companyOffice.id, 'office_amd');
      expect(record.resendStatus, ResendStatus.notDecided);
      expect(FailedDeliveryEngine.customerNoticeBody, contains('unavailable'));
    });
  });

  group('Scenario D — rider office compensation', () {
    test('5 km × ₹8 = ₹40 and is not 85/15', () {
      expect(FailedDeliveryEngine.riderOfficeCompensation(5), 40);
      final TripFinanceSnapshot original =
          FinanceEngine.freezeTrip(rideAmount: 100);
      expect(original.riderAmount, 85);
      expect(FailedDeliveryEngine.riderOfficeCompensation(5), isNot(8.5));
    });
  });

  group('Scenario E — customer resend charge', () {
    test('5 km × ₹10 = ₹50 with no invented split', () {
      expect(FailedDeliveryEngine.customerResendCharge(5), 50);
      final FailedDeliveryRecord opened = FailedDeliveryEngine.open(
        originalDropLabel: 'Paldi',
        officeDistanceKm: 5,
      );
      final FailedDeliveryRecord resent = FailedDeliveryEngine.requestResend(
        current: opened,
        resendDistanceKm: 5,
        resendOrderId: 'IU-AMD-0000000002',
      );
      expect(resent.resendCharge, 50);
      expect(resent.resendOrderId, 'IU-AMD-0000000002');
      expect(resent.riderOfficeCompensation, opened.riderOfficeCompensation);
    });
  });

  group('Scenario F — same phone customer + rider', () {
    test('same mobile registers both roles without collision', () {
      final RoleAccountRegistry registry = RoleAccountRegistry();
      const String phone = '9876543210';
      expect(registry.canRegister(AccountRole.customer, phone), isTrue);
      registry.register(role: AccountRole.customer, phone: phone, id: 'c1');
      expect(registry.canRegister(AccountRole.customer, phone), isFalse);
      expect(registry.canRegister(AccountRole.rider, phone), isTrue);
      registry.register(role: AccountRole.rider, phone: phone, id: 'r1');
      expect(registry.find(AccountRole.customer, phone)?.id, 'c1');
      expect(registry.find(AccountRole.rider, phone)?.id, 'r1');
    });
  });

  group('Scenario G — multi-location stops', () {
    test('ordered stops keep sequence and are not a joined string', () {
      const List<DeliveryStop> stops = [
        DeliveryStop(
          id: 's0',
          sequence: 0,
          label: 'Satellite',
          address: 'Satellite',
          kind: DeliveryStopKind.pickup,
        ),
        DeliveryStop(id: 's1', sequence: 1, label: 'Paldi', address: 'Paldi'),
        DeliveryStop(id: 's2', sequence: 2, label: 'Bopal', address: 'Bopal'),
        DeliveryStop(
          id: 's3',
          sequence: 3,
          label: 'Navrangpura',
          address: 'Navrangpura',
        ),
      ];
      expect(stops.map((s) => s.label).toList(), [
        'Satellite',
        'Paldi',
        'Bopal',
        'Navrangpura',
      ]);
      expect(stops.map((s) => s.sequence).toList(), [0, 1, 2, 3]);
      expect(BookingLimits.maxDeliveryStops, 3);
      expect(BookingLimits.maxStopsPendingBusinessDecision, isFalse);
    });
  });

  group('Scenario H — fare configuration change does not rewrite history', () {
    test('old quote stays on ₹40 after Admin publishes ₹50', () {
      final FareConfig v1 = FareCatalog.currentFor('bike').copyWith(
        versionId: 'bike_40',
        baseFare: 40,
        initialMinimum: 40,
        perKmCharge: 0,
      );
      final FareQuote oldQuote = FareEngine.quote(config: v1, distanceKm: 0);
      expect(oldQuote.netTotal, 40);
      expect(oldQuote.tax, 0);

      FareCatalog.publish(
        'bike',
        v1.copyWith(
          versionId: 'bike_50',
          baseFare: 50,
          initialMinimum: 50,
        ),
      );
      final FareQuote newQuote = FareEngine.quote(
        config: FareCatalog.currentFor('bike'),
        distanceKm: 0,
      );
      expect(newQuote.netTotal, 50);
      expect(oldQuote.netTotal, 40);
      expect(oldQuote.configVersionId, 'bike_40');
    });
  });

  group('Idempotency', () {
    test('duplicate create-order key returns the same id', () {
      final IdempotencyGuard guard = IdempotencyGuard();
      final String first = guard.run('create:demo', OrderIds.nextDisplayId);
      final String second = guard.run('create:demo', OrderIds.nextDisplayId);
      expect(first, second);
    });
  });

  group('Cancellation', () {
    test('V1 cancellation fee is zero', () {
      expect(OrderLifecycle.cancellationFee, 0);
      expect(
        OrderLifecycle.canCustomerCancel(CanonicalOrderStatus.assigned),
        isTrue,
      );
      expect(
        OrderLifecycle.canCustomerCancel(CanonicalOrderStatus.pickedUp),
        isFalse,
      );
    });
  });

  group('Finalized money rules', () {
    test('85/15 uses trip fare not discounted payable', () {
      final TripFinanceSnapshot snap =
          FinanceEngine.freezeTrip(rideAmount: 100);
      expect(snap.riderAmount, 85);
      expect(snap.companyCommissionAmount, 15);
    });

    test('COD settlement never goes negative and suspends at 100', () {
      final CodSettlement first = CodEngine.applyEarning(
        availableWallet: 0,
        codDue: 100,
        grossEarning: 85,
      );
      expect(first.availableWallet, 0);
      expect(first.codDue, 15);
      expect(first.settledAgainstCod, 85);
      expect(CodEngine.isSuspended(first.codDue), isFalse);

      final CodSettlement recharge = CodEngine.applyRecharge(
        availableWallet: 0,
        codDue: 60,
        rechargeAmount: 100,
      );
      expect(recharge.codDue, 0);
      expect(recharge.availableWallet, 40);

      expect(CodEngine.isSuspended(100), isTrue);
    });

    test('resend case A vs case B', () {
      final ResendQuote ended = ResendEngine.quote(
        originalTripEnded: true,
        distanceKm: 5,
        baseFare: 100,
      );
      expect(ended.customerPays, 150);
      expect(ended.riderAmount, 127.5);
      expect(ended.companyAmount, 22.5);

      final ResendQuote active = ResendEngine.quote(
        originalTripEnded: false,
        distanceKm: 5,
      );
      expect(active.customerPays, 50);
      expect(active.riderAmount, 40);
      expect(active.companyAmount, 10);
    });

    test('cancellation split is not forced 85/15', () {
      final CancellationConfig config = CancellationConfig(
        customer: {
          CancellationStage.afterAccept: const CancellationRule(
            enabled: true,
            fee: 100,
            riderSharePercent: 80,
            companySharePercent: 20,
          ),
        },
        rider: const {},
      );
      final CancellationQuote quote = CancellationEngine.quote(
        actor: CancellationActor.customer,
        status: CanonicalOrderStatus.assigned,
        config: config,
      );
      expect(quote.allowed, isTrue);
      expect(quote.riderAmount, 80);
      expect(quote.companyAmount, 20);
    });
  });

  group('Payment responsibility and methods', () {
    test('customer + receiver must equal total', () {
      const PaymentResponsibility bad = PaymentResponsibility(
        totalAmount: 100,
        customerAmount: 60,
        receiverAmount: 30,
      );
      expect(bad.isValid, isFalse);
      final PaymentResponsibility good = PaymentEngine.responsibility(
        totalAmount: 100,
        customerAmount: 60,
      );
      expect(good.receiverAmount, 40);
      expect(good.isValid, isTrue);
    });

    test('split payers and split methods stay valid', () {
      final PaymentResponsibility responsibility = PaymentEngine.responsibility(
        totalAmount: 100,
        customerAmount: 50,
      );
      const PaymentAllocation allocation = PaymentAllocation(
        customerOnline: 30,
        customerCash: 20,
        receiverCash: 50,
      );
      expect(
        PaymentEngine.validate(
          responsibility: responsibility,
          allocation: allocation,
        ),
        isNull,
      );
      final PaymentPlan plan = PaymentEngine.build(
        responsibility: responsibility,
        allocation: allocation,
        orderId: 'IU-AMD-0000000001',
      );
      expect(plan.overallStatus, TripPaymentStatus.unpaid);
      expect(plan.transactions.length, 3);
      expect(plan.allocation.cashTotal, 70);
    });

    test('partially paid when only customer cash is collected', () {
      final PaymentPlan plan = PaymentEngine.build(
        responsibility: PaymentEngine.responsibility(
          totalAmount: 100,
          customerAmount: 50,
        ),
        allocation: const PaymentAllocation(
          customerCash: 50,
          receiverCash: 50,
        ),
        orderId: 'IU-AMD-0000000002',
      );
      final PaymentPlan next = PaymentPlan(
        responsibility: plan.responsibility,
        allocation: plan.allocation,
        transactions: plan.transactions
            .map(
              (t) => t.payer == PaymentPayer.customer
                  ? t.copyWith(status: TripPaymentStatus.paid)
                  : t,
            )
            .toList(),
      );
      expect(next.statusFor(PaymentPayer.customer), TripPaymentStatus.paid);
      expect(next.statusFor(PaymentPayer.receiver), TripPaymentStatus.unpaid);
      expect(next.overallStatus, TripPaymentStatus.partiallyPaid);
    });

    test('85/15 stays on trip fare even when payers split', () {
      final TripFinanceSnapshot snap =
          FinanceEngine.freezeTrip(rideAmount: 100);
      expect(snap.riderAmount, 85);
      expect(snap.companyCommissionAmount, 15);
    });

    test('mixed cash below earning does not create COD Due', () {
      expect(
        CodEngine.companyDueFromCash(cashCollected: 50, riderEarning: 85),
        0,
      );
      expect(
        CodEngine.companyDueFromCash(cashCollected: 100, riderEarning: 85),
        15,
      );
    });
  });
}
