import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { UnconfiguredPaymentProvider } from './unconfigured-payment.provider';
import { PaymentsService } from './payments.service';

const ORDER_ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const PROFILE_ID = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const IDENTITY_ID = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

const customerAuth: AuthContext = {
  identityId: IDENTITY_ID,
  sessionId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
  role: 'CUSTOMER',
  profileId: PROFILE_ID,
};

const adminAuth: AuthContext = {
  ...customerAuth,
  role: 'ADMIN',
  profileId: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
};

function makeService(opts?: {
  remainingOwed?: string;
  availableForPending?: string;
  beginOnlineCharge?: jest.Mock;
}) {
  const remaining = opts?.remainingOwed ?? '100.00';
  const available = opts?.availableForPending ?? remaining;
  const inserted: Record<string, unknown>[] = [];
  const tx = {
    query: jest.fn(),
  };
  const postgres = {
    transaction: async (work: (client: typeof tx) => Promise<unknown>) =>
      work(tx),
  };
  const orders = {
    lockById: jest.fn(async () => ({
      order_id: ORDER_ID,
      display_id: 'IU-TEST-0000000001',
      customer_profile_id: PROFILE_ID,
      rider_profile_id: null,
    })),
  };
  const fares = {
    findSnapshotByOrder: jest.fn(async () => ({
      tax: '0.00',
      trip_fare: '100.00',
      net_payable: '100.00',
    })),
  };
  const payments = {
    findResponsibility: jest.fn(async () => ({
      customer_responsibility: '100.00',
      receiver_responsibility: '0.00',
      who_pays: 'CUSTOMER',
    })),
    findPlan: jest.fn(async () => ({})),
    remainingOwed: jest.fn(async () => remaining),
    availableForPendingOnline: jest.fn(async () => available),
    amountExceeds: jest.fn(async (left: string, right: string) => {
      const [a, b] = await Promise.all([
        Promise.resolve(left),
        Promise.resolve(right),
      ]);
      return Number.parseInt(a.replace('.', ''), 10) >
        Number.parseInt(b.replace('.', ''), 10);
    }),
    findActiveMethodPolicy: jest.fn(async () => null),
    insertTransaction: jest.fn(async (input: Record<string, unknown>) => {
      const row = {
        payment_transaction_id: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
        order_id: input.orderId,
        payer_type: input.payerType,
        method: input.method,
        amount: input.amount,
        direction: input.direction,
        transaction_status: input.status,
        created_by_type: input.createdByType,
        created_at: new Date('2026-09-19T00:00:00.000Z'),
        updated_at: new Date('2026-09-19T00:00:00.000Z'),
      };
      inserted.push(row);
      return row;
    }),
  };
  const idempotency = {
    find: jest.fn(async () => null),
    insert: jest.fn(async () => undefined),
  };
  const walletCod = {
    syncOrderFinance: jest.fn(async () => undefined),
  };
  const paymentNotifications = {
    onTransactionRecorded: jest.fn(async () => undefined),
  };
  const identities = {};
  const beginOnlineCharge =
    opts?.beginOnlineCharge ??
    jest.fn((input: unknown) =>
      new UnconfiguredPaymentProvider().beginOnlineCharge(
        input as {
          orderId: string;
          amount: string;
          payerType: 'CUSTOMER' | 'RECEIVER';
        },
      ),
    );
  const provider = { beginOnlineCharge };
  const gateway = { insertAttempt: jest.fn(async () => undefined) };
  const service = new PaymentsService(
    postgres as never,
    orders as never,
    fares as never,
    payments as never,
    idempotency as never,
    walletCod as never,
    paymentNotifications as never,
    identities as never,
    provider as never,
    gateway as never,
  );
  return {
    service,
    payments,
    provider,
    beginOnlineCharge,
    inserted,
    walletCod,
  };
}

describe('PaymentsService createTransaction', () => {
  it('stores ONLINE charges as PENDING using INR text from the bill remainder, not a client PAID flag', async () => {
    const { service, beginOnlineCharge, inserted, walletCod } = makeService();
    const payload = await service.createTransaction(
      customerAuth,
      ORDER_ID,
      {
        payer_type: 'CUSTOMER',
        method: 'ONLINE',
        amount: '100.00',
        transaction_status: 'PENDING',
      },
      'idem-online-1',
    );
    expect(beginOnlineCharge).toHaveBeenCalledWith({
      orderId: ORDER_ID,
      amount: '100.00',
      payerType: 'CUSTOMER',
    });
    expect(inserted[0].transaction_status).toBe('PENDING');
    expect(payload).toMatchObject({
      transaction_status: 'PENDING',
      amount: '100.00',
      method: 'ONLINE',
    });
    expect(walletCod.syncOrderFinance).not.toHaveBeenCalled();
  });

  it('rejects a second pending online charge that would reserve more than the bill', async () => {
    const { service, beginOnlineCharge, inserted } = makeService({
      availableForPending: '0.00',
    });
    await expect(
      service.createTransaction(
        customerAuth,
        ORDER_ID,
        {
          payer_type: 'CUSTOMER',
          method: 'ONLINE',
          amount: '100.00',
        },
        'idem-online-reserved',
      ),
    ).rejects.toMatchObject({
      code: ErrorCodes.PAYMENT_EXCEEDS_OWED,
      status: 409,
    });
    expect(beginOnlineCharge).not.toHaveBeenCalled();
    expect(inserted).toHaveLength(0);
  });

  it('rejects an ONLINE amount above remaining owed and does not call the provider', async () => {
    const { service, beginOnlineCharge, inserted } = makeService({
      remainingOwed: '50.00',
    });
    await expect(
      service.createTransaction(
        customerAuth,
        ORDER_ID,
        {
          payer_type: 'CUSTOMER',
          method: 'ONLINE',
          amount: '50.01',
        },
        'idem-online-over',
      ),
    ).rejects.toMatchObject({
      code: ErrorCodes.PAYMENT_EXCEEDS_OWED,
      status: 409,
    });
    expect(beginOnlineCharge).not.toHaveBeenCalled();
    expect(inserted).toHaveLength(0);
  });

  it('rejects a CASH amount above remaining owed so a client cannot choose an arbitrary collection', async () => {
    const { service, inserted } = makeService({ remainingOwed: '40.00' });
    await expect(
      service.createTransaction(
        adminAuth,
        ORDER_ID,
        {
          payer_type: 'CUSTOMER',
          method: 'CASH',
          amount: '40.01',
        },
        'idem-cash-over',
      ),
    ).rejects.toMatchObject({
      code: ErrorCodes.PAYMENT_EXCEEDS_OWED,
      status: 409,
    });
    expect(inserted).toHaveLength(0);
  });

  it('does not let a customer record a refund', async () => {
    const { service } = makeService();
    await expect(
      service.createTransaction(
        customerAuth,
        ORDER_ID,
        {
          payer_type: 'CUSTOMER',
          method: 'CASH',
          amount: '10.00',
          direction: 'REFUND',
        },
        'idem-refund',
      ),
    ).rejects.toBeInstanceOf(ApiError);
    await expect(
      service.createTransaction(
        customerAuth,
        ORDER_ID,
        {
          payer_type: 'CUSTOMER',
          method: 'CASH',
          amount: '10.00',
          direction: 'REFUND',
        },
        'idem-refund',
      ),
    ).rejects.toMatchObject({
      code: ErrorCodes.FORBIDDEN,
      status: 403,
    });
  });
});
