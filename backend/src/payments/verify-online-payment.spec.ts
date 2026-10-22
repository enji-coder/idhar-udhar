import { AuthContext } from '../auth/types/auth-context';
import { cashfreeOrderOutcome, PaymentsService } from './payments.service';

const ORDER_ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const PROFILE_ID = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const TX_ID = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const ATTEMPT_ID = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const RIDER_PROFILE_ID = '11111111-1111-1111-1111-111111111111';

const customerAuth: AuthContext = {
  identityId: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  sessionId: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
  role: 'CUSTOMER',
  profileId: PROFILE_ID,
};

describe('cashfreeOrderOutcome', () => {
  it('maps Cashfree order_status values', () => {
    expect(cashfreeOrderOutcome('PAID')).toBe('success');
    expect(cashfreeOrderOutcome('EXPIRED')).toBe('failed');
    expect(cashfreeOrderOutcome('ACTIVE')).toBe('pending');
  });

  it('maps every supported terminal failure status to failed', () => {
    for (const status of [
      'EXPIRED',
      'CANCELLED',
      'TERMINATED',
      'FAILED',
      'USER_DROPPED',
    ] as const) {
      expect(cashfreeOrderOutcome(status)).toBe('failed');
    }
  });

  it('treats non-terminal statuses as pending', () => {
    expect(cashfreeOrderOutcome('ACTIVE')).toBe('pending');
    expect(cashfreeOrderOutcome('')).toBe('pending');
  });
});

describe('PaymentsService.verifyOnlinePayment', () => {
  function makeVerifyService(opts: {
    orderStatus: string;
    orderAmount?: string;
    currentStatus?: 'PENDING' | 'PAID' | 'FAILED';
    chargePurpose?: 'BOOKING' | 'RECEIVABLE_CLEARANCE' | 'WALLET_TOPUP';
    riderProfileId?: string | null;
  }) {
    let transactionStatus = opts.currentStatus ?? 'PENDING';
    let gatewayStatus = 'ACTIVE';
    let casGate = Promise.resolve();
    async function withCasGate<T>(work: () => T | Promise<T>): Promise<T> {
      const previous = casGate;
      let release!: () => void;
      casGate = new Promise<void>((resolve) => {
        release = resolve;
      });
      await previous;
      try {
        return await work();
      } finally {
        release();
      }
    }
    const tx = {
      query: jest.fn(async (sql: string) =>
        withCasGate(async () => {
          if (sql.includes("transaction_status = 'PAID'")) {
            if (
              transactionStatus === 'PENDING' ||
              transactionStatus === 'FAILED'
            ) {
              transactionStatus = 'PAID';
              return { rows: [{ payment_transaction_id: TX_ID }] };
            }
            return { rows: [] };
          }
          if (sql.includes("transaction_status = 'FAILED'")) {
            if (transactionStatus === 'PENDING') {
              transactionStatus = 'FAILED';
              return { rows: [{ payment_transaction_id: TX_ID }] };
            }
            return { rows: [] };
          }
          return { rows: [] };
        }),
      ),
    };
    const callOrder: string[] = [];
    const postgres = {
      transaction: jest.fn(async (work: (client: typeof tx) => Promise<unknown>) => {
        callOrder.push('transaction');
        return work(tx);
      }),
    };
    const order = {
      order_id: ORDER_ID,
      display_id: 'IU-TEST-1',
      customer_profile_id: PROFILE_ID,
      rider_profile_id: null,
    };
    const orders = {
      findById: jest.fn(async () => order),
      lockById: jest.fn(async () => order),
    };
    const payments = {
      findTransaction: jest.fn(async () => ({
        payment_transaction_id: TX_ID,
        order_id: ORDER_ID,
        amount: '40.00',
        transaction_status: transactionStatus,
      })),
      amountsEqual: jest.fn(async (left: string, right: string) => left === right),
    };
    const walletCod = {
      syncOrderFinance: jest.fn(async () => undefined),
      applyVerifiedWalletTopUp: jest.fn(async () => undefined),
    };
    const paymentNotifications = {
      onTransactionRecorded: jest.fn(async () => undefined),
    };
    const settlement = {
      creditOnlineClearance: jest.fn(async () => undefined),
      waitingSummary: jest.fn(async () => null),
      orderOutstanding: jest.fn(async () => '0.00'),
    };
    const gateway = {
      findByTransaction: jest.fn(async () => ({
        payment_gateway_attempt_id: ATTEMPT_ID,
        payment_transaction_id: TX_ID,
        gateway_order_id: 'iu-order-1',
        gateway_status: gatewayStatus,
        transaction_status: transactionStatus,
        transaction_amount: '40.00',
        charge_purpose: opts.chargePurpose ?? 'BOOKING',
        rider_profile_id: opts.riderProfileId ?? null,
        order_id: ORDER_ID,
        payer_type: 'CUSTOMER',
      })),
      updateGatewayStatus: jest.fn(async (_id: string, status: string) => {
        gatewayStatus = status;
      }),
      updateAttempt: jest.fn(async (input: { gatewayStatus: string }) => {
        gatewayStatus = input.gatewayStatus;
      }),
    };
    const provider = {
      beginOnlineCharge: jest.fn(),
      retrieveOnlineOrder: jest.fn(async () => {
        callOrder.push('retrieveOnlineOrder');
        return {
          orderStatus: opts.orderStatus,
          orderAmount: opts.orderAmount ?? '40.00',
          orderCurrency: 'INR',
        };
      }),
    };

    const service = new PaymentsService(
      postgres as never,
      orders as never,
      {} as never,
      payments as never,
      { find: jest.fn(), insert: jest.fn() } as never,
      walletCod as never,
      paymentNotifications as never,
      {} as never,
      provider as never,
      gateway as never,
      settlement as never,
    );

    (service as unknown as { requireReadableOrder: Function }).requireReadableOrder =
      async () => order;

    return {
      service,
      walletCod,
      paymentNotifications,
      settlement,
      gateway,
      provider,
      postgres,
      callOrder,
      getStatus: () => transactionStatus,
    };
  }

  it('settles BOOKING to PAID when Cashfree order_status is PAID', async () => {
    const { service, walletCod, paymentNotifications, getStatus } =
      makeVerifyService({ orderStatus: 'PAID' });
    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );
    expect(result).toMatchObject({
      payment_transaction_id: TX_ID,
      transaction_status: 'PAID',
      authoritative: true,
      amount_matches: true,
    });
    expect(getStatus()).toBe('PAID');
    expect(walletCod.syncOrderFinance).toHaveBeenCalledTimes(1);
    expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'PAID' }),
      expect.anything(),
    );
  });

  it('does not settle while Cashfree still reports ACTIVE', async () => {
    const { service, walletCod, getStatus } = makeVerifyService({
      orderStatus: 'ACTIVE',
    });
    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );
    expect(result).toMatchObject({
      transaction_status: 'PENDING',
      authoritative: false,
      amount_matches: true,
    });
    expect(getStatus()).toBe('PENDING');
    expect(walletCod.syncOrderFinance).not.toHaveBeenCalled();
  });

  it('rejects amount mismatches without settling', async () => {
    const { service, walletCod, getStatus } = makeVerifyService({
      orderStatus: 'PAID',
      orderAmount: '99.00',
    });
    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );
    expect(result).toMatchObject({
      transaction_status: 'PENDING',
      authoritative: false,
      amount_matches: false,
    });
    expect(getStatus()).toBe('PENDING');
    expect(walletCod.syncOrderFinance).not.toHaveBeenCalled();
  });

  it('credits receivable clearance when verify settles PAID', async () => {
    const { service, settlement } = makeVerifyService({
      orderStatus: 'PAID',
      chargePurpose: 'RECEIVABLE_CLEARANCE',
    });
    await service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID);
    expect(settlement.creditOnlineClearance).toHaveBeenCalledTimes(1);
  });

  it('does not settle BOOKING or clearance twice on duplicate verify', async () => {
    const { service, walletCod, settlement, paymentNotifications, getStatus } =
      makeVerifyService({ orderStatus: 'PAID' });

    const first = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );
    const second = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(first).toMatchObject({
      transaction_status: 'PAID',
      authoritative: true,
    });
    expect(second).toMatchObject({
      transaction_status: 'PAID',
      authoritative: false,
    });
    expect(getStatus()).toBe('PAID');
    expect(walletCod.syncOrderFinance).toHaveBeenCalledTimes(1);
    expect(settlement.creditOnlineClearance).not.toHaveBeenCalled();
    expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledTimes(1);
  });

  it('does not duplicate RECEIVABLE_CLEARANCE credit on repeated verify', async () => {
    const { service, settlement, paymentNotifications } = makeVerifyService({
      orderStatus: 'PAID',
      chargePurpose: 'RECEIVABLE_CLEARANCE',
    });

    await service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID);
    await service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID);

    expect(settlement.creditOnlineClearance).toHaveBeenCalledTimes(1);
    expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledTimes(1);
  });

  it('recovers FAILED to PAID when Cashfree reports PAID with matching amount', async () => {
    const { service, walletCod, paymentNotifications, getStatus } =
      makeVerifyService({
        orderStatus: 'PAID',
        currentStatus: 'FAILED',
      });

    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(result).toMatchObject({
      transaction_status: 'PAID',
      authoritative: true,
      amount_matches: true,
    });
    expect(getStatus()).toBe('PAID');
    expect(walletCod.syncOrderFinance).toHaveBeenCalledTimes(1);
    expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'PAID' }),
      expect.anything(),
    );
  });

  it('does not credit finance when FAILED recovery amount mismatches', async () => {
    const { service, walletCod, paymentNotifications, getStatus } =
      makeVerifyService({
        orderStatus: 'PAID',
        orderAmount: '99.00',
        currentStatus: 'FAILED',
      });

    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(result).toMatchObject({
      transaction_status: 'FAILED',
      authoritative: false,
      amount_matches: false,
    });
    expect(getStatus()).toBe('FAILED');
    expect(walletCod.syncOrderFinance).not.toHaveBeenCalled();
    expect(paymentNotifications.onTransactionRecorded).not.toHaveBeenCalled();
  });

  it('credits WALLET_TOPUP with rider profile on successful verify', async () => {
    const { service, walletCod, paymentNotifications, settlement, getStatus } =
      makeVerifyService({
        orderStatus: 'PAID',
        chargePurpose: 'WALLET_TOPUP',
        riderProfileId: RIDER_PROFILE_ID,
      });

    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(result).toMatchObject({
      transaction_status: 'PAID',
      authoritative: true,
    });
    expect(getStatus()).toBe('PAID');
    expect(walletCod.applyVerifiedWalletTopUp).toHaveBeenCalledTimes(1);
    expect(walletCod.applyVerifiedWalletTopUp).toHaveBeenCalledWith(
      {
        paymentTransactionId: TX_ID,
        riderProfileId: RIDER_PROFILE_ID,
        amount: '40.00',
      },
      expect.anything(),
    );
    expect(walletCod.syncOrderFinance).not.toHaveBeenCalled();
    expect(settlement.creditOnlineClearance).not.toHaveBeenCalled();
    expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'PAID' }),
      expect.anything(),
    );
  });

  it('does not settle WALLET_TOPUP when rider profile is missing', async () => {
    const { service, walletCod, paymentNotifications, getStatus } =
      makeVerifyService({
        orderStatus: 'PAID',
        chargePurpose: 'WALLET_TOPUP',
        riderProfileId: null,
      });

    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(result).toMatchObject({
      transaction_status: 'PENDING',
      authoritative: false,
      amount_matches: true,
    });
    expect(getStatus()).toBe('PENDING');
    expect(walletCod.applyVerifiedWalletTopUp).not.toHaveBeenCalled();
    expect(paymentNotifications.onTransactionRecorded).not.toHaveBeenCalled();
  });

  it('does not duplicate wallet top-up on repeated successful verify', async () => {
    const { service, walletCod, paymentNotifications } = makeVerifyService({
      orderStatus: 'PAID',
      chargePurpose: 'WALLET_TOPUP',
      riderProfileId: RIDER_PROFILE_ID,
    });

    await service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID);
    await service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID);

    expect(walletCod.applyVerifiedWalletTopUp).toHaveBeenCalledTimes(1);
    expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledTimes(1);
  });

  it.each([
    'EXPIRED',
    'CANCELLED',
    'TERMINATED',
    'FAILED',
    'USER_DROPPED',
  ] as const)(
    'marks PENDING as FAILED when Cashfree reports %s',
    async (orderStatus) => {
      const { service, walletCod, settlement, paymentNotifications, getStatus } =
        makeVerifyService({ orderStatus });

      const result = await service.verifyOnlinePayment(
        customerAuth,
        ORDER_ID,
        TX_ID,
      );

      expect(result).toMatchObject({
        transaction_status: 'FAILED',
        authoritative: true,
        amount_matches: true,
      });
      expect(getStatus()).toBe('FAILED');
      expect(walletCod.syncOrderFinance).not.toHaveBeenCalled();
      expect(settlement.creditOnlineClearance).not.toHaveBeenCalled();
      expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledTimes(1);
      expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'FAILED' }),
        expect.anything(),
      );
    },
  );

  it('does not re-fail an already FAILED charge on terminal Cashfree status', async () => {
    const { service, paymentNotifications, getStatus } = makeVerifyService({
      orderStatus: 'EXPIRED',
      currentStatus: 'FAILED',
    });

    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(result).toMatchObject({
      transaction_status: 'FAILED',
      authoritative: false,
    });
    expect(getStatus()).toBe('FAILED');
    expect(paymentNotifications.onTransactionRecorded).not.toHaveBeenCalled();
  });

  it('never settles RECEIVABLE_CLEARANCE while Cashfree is ACTIVE', async () => {
    const { service, settlement, paymentNotifications, getStatus } =
      makeVerifyService({
        orderStatus: 'ACTIVE',
        chargePurpose: 'RECEIVABLE_CLEARANCE',
      });

    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(result).toMatchObject({
      transaction_status: 'PENDING',
      authoritative: false,
    });
    expect(getStatus()).toBe('PENDING');
    expect(settlement.creditOnlineClearance).not.toHaveBeenCalled();
    expect(paymentNotifications.onTransactionRecorded).not.toHaveBeenCalled();
  });

  it('never credits clearance on amount mismatch even when Cashfree is PAID', async () => {
    const { service, settlement, paymentNotifications, getStatus } =
      makeVerifyService({
        orderStatus: 'PAID',
        orderAmount: '12.00',
        chargePurpose: 'RECEIVABLE_CLEARANCE',
      });

    const result = await service.verifyOnlinePayment(
      customerAuth,
      ORDER_ID,
      TX_ID,
    );

    expect(result).toMatchObject({
      amount_matches: false,
      authoritative: false,
      transaction_status: 'PENDING',
    });
    expect(getStatus()).toBe('PENDING');
    expect(settlement.creditOnlineClearance).not.toHaveBeenCalled();
    expect(paymentNotifications.onTransactionRecorded).not.toHaveBeenCalled();
  });

  it('retrieves Cashfree before opening the settle transaction', async () => {
    const { service, callOrder } = makeVerifyService({ orderStatus: 'PAID' });
    await service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID);
    expect(callOrder.indexOf('retrieveOnlineOrder')).toBeGreaterThanOrEqual(0);
    expect(callOrder.indexOf('transaction')).toBeGreaterThan(
      callOrder.indexOf('retrieveOnlineOrder'),
    );
  });

  it('credits WALLET_TOPUP only once under concurrent verify', async () => {
    const { service, walletCod, paymentNotifications, getStatus } =
      makeVerifyService({
        orderStatus: 'PAID',
        chargePurpose: 'WALLET_TOPUP',
        riderProfileId: RIDER_PROFILE_ID,
      });

    const [first, second] = await Promise.all([
      service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID),
      service.verifyOnlinePayment(customerAuth, ORDER_ID, TX_ID),
    ]);

    const authoritative = [first, second].filter((row) => row.authoritative);
    expect(authoritative).toHaveLength(1);
    expect(getStatus()).toBe('PAID');
    expect(walletCod.applyVerifiedWalletTopUp).toHaveBeenCalledTimes(1);
    expect(paymentNotifications.onTransactionRecorded).toHaveBeenCalledTimes(1);
  });
});
