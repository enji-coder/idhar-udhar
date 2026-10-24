import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { OrderAdminDeletionService } from './order-admin-deletion.service';
import { OrdersRepository } from './orders.repository';

const admin: AuthContext = {
  identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  sessionId: 'session',
  role: 'ADMIN',
  profileId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
};

const rider: AuthContext = { ...admin, role: 'RIDER' };

const body = {
  reason: 'Remove unused historical test order',
  confirm_display_id: 'IU-AMD-0000000001',
  confirm_crn: 'IU-CRN-AMD-0000000001',
};

function service(overrides: Record<string, unknown> = {}) {
  const orders = {
    lockDeletionTarget: jest.fn(async () => ({
      order_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      display_id: body.confirm_display_id,
      crn: body.confirm_crn,
      canonical_status: 'CANCELLED',
      removed_from_operations_at: null,
    })),
    dependencyCounts: jest.fn(async () => ({
      payments: 0,
      wallet: 0,
      cod: 0,
      customer_wallet: 0,
      receivables: 0,
      invoices: 0,
      finance: 0,
      cancellations: 0,
      adjustments: 0,
      resends: 0,
      tax: 0,
      children: 0,
      waiting: 0,
    })),
    purgeEligibleOrder: jest.fn(async () => undefined),
    hideFromOperations: jest.fn(async () => true),
    findById: jest.fn(async () => ({
      order_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      display_id: body.confirm_display_id,
      crn: body.confirm_crn,
      canonical_status: 'DELIVERED',
    })),
    ...overrides,
  };
  const audit = {
    record: jest.fn(async () => undefined),
    recordRequired: jest.fn(async () => undefined),
  };
  const postgres = {
    transaction: async (work: (tx: object) => Promise<unknown>) => work({}),
  };
  return {
    service: new OrderAdminDeletionService(
      postgres as never,
      orders as unknown as OrdersRepository,
      audit as never,
    ),
    orders,
    audit,
  };
}

describe('OrderAdminDeletionService', () => {
  it('rejects a rider', async () => {
    const { service: deletion, orders } = service();
    await expect(deletion.purge(rider, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', body)).rejects.toMatchObject({
      code: ErrorCodes.FORBIDDEN,
    });
    expect(orders.purgeEligibleOrder).not.toHaveBeenCalled();
  });

  it('rejects a mismatched CRN before deleting anything', async () => {
    const { service: deletion, orders } = service();
    await expect(deletion.purge(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', {
      ...body,
      confirm_crn: 'IU-CRN-AMD-9999999999',
    })).rejects.toMatchObject({
      status: 422,
      details: undefined,
    });
    expect(orders.purgeEligibleOrder).not.toHaveBeenCalled();
  });

  it('rejects a blank reason before locking the order', async () => {
    const { service: deletion, orders } = service();
    await expect(deletion.purge(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', {
      ...body,
      reason: '        ',
    })).rejects.toMatchObject({ status: 422 });
    expect(orders.lockDeletionTarget).not.toHaveBeenCalled();
  });

  it('purges an eligible cancelled order and writes an audit row first', async () => {
    const { service: deletion, orders, audit } = service();
    const result = await deletion.purge(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', body);
    expect(result.result).toBe('purged');
    expect(audit.recordRequired).toHaveBeenCalled();
    expect(orders.purgeEligibleOrder).toHaveBeenCalled();
  });

  it('does not purge when a finance snapshot exists', async () => {
    const { service: deletion, orders } = service({
      dependencyCounts: jest.fn(async () => ({
        payments: 0,
        wallet: 0,
        cod: 0,
        customer_wallet: 0,
        receivables: 0,
        invoices: 0,
        finance: 1,
        cancellations: 0,
        adjustments: 0,
        resends: 0,
        tax: 0,
        children: 0,
        waiting: 0,
      })),
    });
    await expect(deletion.purge(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', body)).rejects.toMatchObject({
      code: ErrorCodes.ORDER_FINANCIAL_DEPENDENCY,
    });
    expect(orders.purgeEligibleOrder).not.toHaveBeenCalled();
  });

  it('hides a financially dependent order without deleting it', async () => {
    const { service: deletion, orders } = service();
    const result = await deletion.hide(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', body);
    expect(result.result).toBe('removed_from_operations');
    expect(orders.purgeEligibleOrder).not.toHaveBeenCalled();
    expect(orders.hideFromOperations).toHaveBeenCalled();
  });

  it('returns the same result when the order was already hidden', async () => {
    const { service: deletion, orders, audit } = service({
      lockDeletionTarget: jest.fn(async () => ({
        order_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        display_id: body.confirm_display_id,
        crn: body.confirm_crn,
        canonical_status: 'CANCELLED',
        removed_from_operations_at: new Date('2026-01-01T00:00:00.000Z'),
      })),
    });
    const result = await deletion.hide(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', body);
    expect(result.result).toBe('already_removed');
    expect(orders.hideFromOperations).not.toHaveBeenCalled();
    expect(audit.recordRequired).not.toHaveBeenCalled();
  });

  it('rejects a new invoice for a cancelled order', async () => {
    const { service: deletion } = service({
      findById: jest.fn(async () => ({
        order_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        display_id: body.confirm_display_id,
        crn: body.confirm_crn,
        canonical_status: 'CANCELLED',
      })),
    });
    await expect(deletion.assertInvoiceAllowed(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc')).rejects.toMatchObject({
      code: ErrorCodes.INVOICE_ORDER_CANCELLED,
    });
  });

  it('does not purge when the mandatory audit insert fails', async () => {
    let purged = false;
    let committed = false;
    const orders = {
      lockDeletionTarget: jest.fn(async () => ({
        order_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        display_id: body.confirm_display_id,
        crn: body.confirm_crn,
        canonical_status: 'CANCELLED',
        removed_from_operations_at: null,
      })),
      dependencyCounts: jest.fn(async () => ({
        payments: 0,
        wallet: 0,
        cod: 0,
        customer_wallet: 0,
        receivables: 0,
        invoices: 0,
        finance: 0,
        cancellations: 0,
        adjustments: 0,
        resends: 0,
        tax: 0,
        children: 0,
        waiting: 0,
      })),
      purgeEligibleOrder: jest.fn(async () => {
        purged = true;
      }),
    };
    const postgres = {
      transaction: async (work: (tx: object) => Promise<unknown>) => {
        try {
          const result = await work({});
          committed = true;
          return result;
        } catch (err) {
          purged = false;
          committed = false;
          throw err;
        }
      },
    };
    const guarded = new OrderAdminDeletionService(
      postgres as never,
      orders as unknown as OrdersRepository,
      { recordRequired: jest.fn(async () => { throw new Error('audit insert failed'); }) } as never,
    );
    await expect(guarded.purge(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', body)).rejects.toThrow(
      'audit insert failed',
    );
    expect(purged).toBe(false);
    expect(committed).toBe(false);
    expect(orders.purgeEligibleOrder).not.toHaveBeenCalled();
  });

  it('rolls back a hide when the mandatory audit insert fails', async () => {
    let hidden = false;
    let committed = false;
    const orders = {
      lockDeletionTarget: jest.fn(async () => ({
        order_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        display_id: body.confirm_display_id,
        crn: body.confirm_crn,
        canonical_status: 'CANCELLED',
        removed_from_operations_at: null,
      })),
      hideFromOperations: jest.fn(async () => {
        hidden = true;
        return true;
      }),
    };
    const audit = {
      recordRequired: jest.fn(async () => {
        throw new Error('audit insert failed');
      }),
    };
    const postgres = {
      transaction: async (work: (tx: object) => Promise<unknown>) => {
        const before = hidden;
        try {
          const result = await work({});
          committed = true;
          return result;
        } catch (err) {
          hidden = before;
          committed = false;
          throw err;
        }
      },
    };
    const guarded = new OrderAdminDeletionService(
      postgres as never,
      orders as unknown as OrdersRepository,
      audit as never,
    );
    await expect(guarded.hide(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', body)).rejects.toThrow(
      'audit insert failed',
    );
    expect(hidden).toBe(false);
    expect(committed).toBe(false);
  });

  it('allows the invoice check for a delivered order', async () => {
    const { service: deletion } = service();
    await expect(deletion.assertInvoiceAllowed(admin, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc')).resolves.toMatchObject({
      invoice_allowed: true,
      crn: body.confirm_crn,
    });
  });
});
