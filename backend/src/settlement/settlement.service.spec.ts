import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { Queryable } from '../database/queryable';
import { OrderRow } from '../orders/orders.repository';
import {
  RECEIVABLE_OUTSTANDING_CASE,
  SettlementRepository,
  WaitingChargeRow,
} from './settlement.repository';
import { SettlementService } from './settlement.service';

const ORDER = '11111111-1111-4111-8111-111111111111';
const CUSTOMER = '22222222-2222-4222-8222-222222222222';
const WAITING = '33333333-3333-4333-8333-333333333333';
const WALLET = '44444444-4444-4444-8444-444444444444';

function db(tripFare = '135.00'): Queryable {
  return {
    query: jest.fn(async () => ({ rows: [{ trip_fare: tripFare }], rowCount: 1 })),
  } as unknown as Queryable;
}

function waiting(amount: string, status: WaitingChargeRow['settlement_status'] = 'OPEN'): WaitingChargeRow {
  return {
    order_waiting_charge_id: WAITING,
    order_id: ORDER,
    amount,
    settlement_status: status,
    initial_waiting_minutes: 10,
    waiting_charge_per_minute: '1.00',
    chargeable_minutes: Number(amount),
  };
}

function order(): OrderRow {
  return {
    order_id: ORDER,
    customer_profile_id: CUSTOMER,
    display_id: 'IU-1',
  } as OrderRow;
}

function harness(debit: string, row = waiting('5.00')) {
  const invoices: Array<Record<string, string>> = [];
  const receivables: Array<Record<string, string>> = [];
  const repo = {
    lockCustomerWallet: jest.fn(async () => ({
      customer_wallet_id: WALLET,
      available_balance: debit,
    })),
    outstanding: jest.fn(async () => '0.00'),
    orderOutstanding: jest.fn(async () => '0.00'),
    findWaiting: jest.fn(async () => row),
    assessPickup: jest.fn(async () => row),
    voidOpenWaiting: jest.fn(async () => undefined),
    markSettled: jest.fn(async () => undefined),
    debitWalletUpTo: jest.fn(async () => debit),
    receivableCredits: jest.fn(async () => '0.00'),
    insertReceivable: jest.fn(async (input: Record<string, string>) => {
      receivables.push(input);
      return true;
    }),
    bookingCustomerPaid: jest.fn(async () => '135.00'),
    bookingReceiverPaid: jest.fn(async () => '0.00'),
    insertInvoice: jest.fn(async (input: Record<string, string>) => {
      invoices.push(input);
    }),
    markInvoicePaidIfSettled: jest.fn(async () => undefined),
  };
  const service = new SettlementService(repo as unknown as SettlementRepository);
  return { service, repo, invoices, receivables };
}

describe('SettlementService', () => {
  it('rejects a new booking while a receivable is outstanding', async () => {
    const { service, repo } = harness('0.00');
    repo.outstanding.mockResolvedValue('3.00');
    await expect(service.assertNoOutstanding(CUSTOMER, db())).rejects.toMatchObject({
      code: ErrorCodes.OUTSTANDING_DUE,
      status: 409,
      details: { outstanding_amount: '3.00' },
    });
    expect(repo.lockCustomerWallet).toHaveBeenCalledWith(CUSTOMER, expect.anything());
  });

  it('allows a booking when outstanding is zero after the wallet lock', async () => {
    const { service, repo } = harness('0.00');
    await expect(service.assertNoOutstanding(CUSTOMER, db())).resolves.toBeUndefined();
    expect(repo.lockCustomerWallet).toHaveBeenCalled();
  });

  it('records the waiting charge as outstanding and does not debit the wallet', async () => {
    const { service, repo, invoices, receivables } = harness('10.00');
    await service.settleDelivered(order(), db());
    expect(repo.debitWalletUpTo).not.toHaveBeenCalled();
    expect(receivables.map((row) => row.entryType)).toEqual(['WAITING_ASSESSMENT']);
    expect(invoices[0]).toMatchObject({
      tripFare: '135.00',
      additional: '5.00',
      billedTotal: '140.00',
      customerPaid: '135.00',
      paymentStatus: 'PARTIALLY_PAID',
    });
    expect(repo.markSettled).toHaveBeenCalledWith(WAITING, expect.anything());
  });

  it('includes an explicit waiting payment already collected and still does not debit the wallet', async () => {
    const { service, repo, invoices } = harness('10.00');
    repo.receivableCredits.mockResolvedValue('5.00');
    await service.settleDelivered(order(), db());
    expect(repo.debitWalletUpTo).not.toHaveBeenCalled();
    expect(invoices[0]).toMatchObject({
      billedTotal: '140.00',
      customerPaid: '140.00',
      paymentStatus: 'PAID',
    });
  });

  it('does not debit again when settlement already completed', async () => {
    const { service, repo } = harness('5.00', waiting('5.00', 'SETTLED'));
    await service.settleDelivered(order(), db());
    expect(repo.debitWalletUpTo).not.toHaveBeenCalled();
    expect(repo.insertInvoice).not.toHaveBeenCalled();
  });

  it('does not debit a voided assessment', async () => {
    const { service, repo } = harness('5.00', waiting('5.00', 'VOID'));
    await service.settleDelivered(order(), db());
    expect(repo.debitWalletUpTo).not.toHaveBeenCalled();
    expect(repo.insertReceivable).not.toHaveBeenCalled();
  });

  it('credits an online clearance once and does not rewrite the invoice on a repeat', async () => {
    const { service, repo } = harness('2.00', waiting('5.00', 'SETTLED'));
    repo.orderOutstanding.mockResolvedValue('3.00');
    repo.insertReceivable.mockResolvedValueOnce(true).mockResolvedValueOnce(false);
    await service.creditOnlineClearance(
      {
        orderId: ORDER,
        customerProfileId: CUSTOMER,
        amount: '3.00',
        paymentTransactionId: 'pay-1',
      },
      db(),
    );
    await service.creditOnlineClearance(
      {
        orderId: ORDER,
        customerProfileId: CUSTOMER,
        amount: '3.00',
        paymentTransactionId: 'pay-1',
      },
      db(),
    );
    expect(repo.insertReceivable).toHaveBeenCalledTimes(2);
    expect(repo.markInvoicePaidIfSettled).toHaveBeenCalledTimes(1);
    const credit = repo.insertReceivable.mock.calls[0][0] as { entryType: string; idempotencyKey: string };
    expect(credit.entryType).toBe('ONLINE_CLEARANCE');
    expect(credit.idempotencyKey).toBe('online-clearance:pay-1');
  });

  it('rejects a clearance whose amount is not the outstanding receivable', async () => {
    const { service, repo } = harness('2.00', waiting('5.00', 'SETTLED'));
    repo.orderOutstanding.mockResolvedValue('3.00');
    await expect(
      service.creditOnlineClearance(
        {
          orderId: ORDER,
          customerProfileId: CUSTOMER,
          amount: '5.00',
          paymentTransactionId: 'pay-2',
        },
        db(),
      ),
    ).rejects.toBeInstanceOf(ApiError);
    expect(repo.insertReceivable).not.toHaveBeenCalled();
  });

  it('voids an unpaid pickup assessment on cancel and does not debit the wallet', async () => {
    const { service, repo } = harness('10.00');
    repo.findWaiting.mockResolvedValue(waiting('5.00', 'OPEN'));
    repo.receivableCredits.mockResolvedValue('0.00');
    await service.onCancelled(ORDER, db());
    expect(repo.voidOpenWaiting).toHaveBeenCalledWith(ORDER, expect.anything());
    expect(repo.debitWalletUpTo).not.toHaveBeenCalled();
    expect(repo.insertReceivable).not.toHaveBeenCalled();
    expect(outstandingOf([{ direction: 'CHARGE', amount: '5.00', status: 'VOID' }])).toBe(
      '0.00',
    );
    expect(RECEIVABLE_OUTSTANDING_CASE).toContain(
      "WHEN w.settlement_status = 'VOID' THEN 0::numeric(12,2)",
    );
  });

  it('allows the next booking after an unpaid waiting charge is voided', async () => {
    const { service, repo } = harness('10.00');
    repo.findWaiting.mockResolvedValue(waiting('5.00', 'OPEN'));
    repo.receivableCredits.mockResolvedValue('0.00');
    repo.outstanding.mockResolvedValue('5.00');
    await expect(service.assertNoOutstanding(CUSTOMER, db())).rejects.toMatchObject({
      code: ErrorCodes.OUTSTANDING_DUE,
    });
    await service.onCancelled(ORDER, db());
    repo.outstanding.mockResolvedValue(
      outstandingOf([{ direction: 'CHARGE', amount: '5.00', status: 'VOID' }]),
    );
    await expect(service.assertNoOutstanding(CUSTOMER, db())).resolves.toBeUndefined();
    expect(repo.debitWalletUpTo).not.toHaveBeenCalled();
  });

  it('does not void a settled or already paid waiting charge', async () => {
    const settled = harness('10.00', waiting('5.00', 'SETTLED'));
    await settled.service.onCancelled(ORDER, db());
    expect(settled.repo.voidOpenWaiting).not.toHaveBeenCalled();

    const paid = harness('10.00', waiting('5.00', 'OPEN'));
    paid.repo.receivableCredits.mockResolvedValue('5.00');
    await paid.service.onCancelled(ORDER, db());
    expect(paid.repo.voidOpenWaiting).not.toHaveBeenCalled();
    expect(paid.repo.debitWalletUpTo).not.toHaveBeenCalled();
  });

  it('leaves cancellation unchanged when pickup waiting was never assessed', async () => {
    const { service, repo } = harness('10.00');
    repo.findWaiting.mockResolvedValue(null as never);
    await service.onCancelled(ORDER, db());
    expect(repo.voidOpenWaiting).not.toHaveBeenCalled();
    expect(repo.receivableCredits).not.toHaveBeenCalled();
    expect(repo.debitWalletUpTo).not.toHaveBeenCalled();
    expect(repo.insertReceivable).not.toHaveBeenCalled();
  });
});

function outstandingOf(
  rows: Array<{
    direction: 'CHARGE' | 'CREDIT';
    amount: string;
    status: 'OPEN' | 'SETTLED' | 'VOID';
  }>,
): string {
  let paise = 0n;
  for (const row of rows) {
    if (row.status === 'VOID') {
      continue;
    }
    const [whole, frac = ''] = row.amount.split('.');
    const value = BigInt(whole) * 100n + BigInt((frac + '00').slice(0, 2));
    paise += row.direction === 'CHARGE' ? value : -value;
  }
  if (paise < 0n) {
    paise = 0n;
  }
  const whole = paise / 100n;
  const frac = (paise % 100n).toString().padStart(2, '0');
  return `${whole.toString()}.${frac}`;
}
