import { ErrorCodes } from '../common/errors/error-codes';
import { OrderRow } from '../orders/orders.repository';
import { FinanceService } from './finance.service';

const ORDER = '55555555-5555-4555-8555-555555555555';
const SNAP = '77777777-7777-4777-8777-777777777777';

function deliveredOrder(): OrderRow {
  return {
    order_id: ORDER,
    canonical_status: 'DELIVERED',
    rider_profile_id: '22222222-2222-4222-8222-222222222222',
  } as OrderRow;
}

describe('FinanceService.captureOnDelivered', () => {
  it('freezes ORIGINAL from trip fare and syncs wallet/COD', async () => {
    const finance = {
      findOriginal: jest.fn(async () => null),
      findActiveSettings: jest.fn(async () => ({ payment_settings_version_id: 'v1' })),
      insertOriginalFromFareSnapshot: jest.fn(async () => ({
        finance_snapshot_id: SNAP,
        order_id: ORDER,
        snapshot_kind: 'ORIGINAL',
        trip_fare: '100.00',
        rider_amount: '85.00',
        company_commission_amount: '15.00',
        operational_cost_amount: '7.50',
        profit_amount: '7.50',
        rider_percentage: '85.00',
        company_commission_percentage: '15.00',
        operational_cost_percentage_of_commission: '50.00',
        payment_settings_version_id: 'v1',
        frozen_at: new Date('2026-10-03T00:00:00.000Z'),
      })),
    };
    const fares = {
      findSnapshotByOrder: jest.fn(async () => ({
        fare_snapshot_id: 'f1',
        order_id: ORDER,
        tax: '0.00',
        trip_fare: '100.00',
      })),
    };
    const walletCod = {
      syncOrderFinance: jest.fn(async () => undefined),
    };
    const orderTax = {
      findByFinanceSnapshot: jest.fn(async () => null),
      insertForFinanceSnapshot: jest.fn(async () => ({ order_tax_snapshot_id: 't1' })),
    };
    const service = new FinanceService(
      {} as never,
      {} as never,
      fares as never,
      finance as never,
      walletCod as never,
      {} as never,
      orderTax as never,
      { warn: jest.fn() } as never,
    );

    const result = await service.captureOnDelivered(deliveredOrder(), {} as never);
    expect(result.capture_moment).toBe('DELIVERED');
    expect(finance.insertOriginalFromFareSnapshot).toHaveBeenCalledWith(ORDER, expect.anything());
    expect(walletCod.syncOrderFinance).toHaveBeenCalled();
  });

  it('is idempotent when ORIGINAL already exists', async () => {
    const existing = {
      finance_snapshot_id: SNAP,
      order_id: ORDER,
      snapshot_kind: 'ORIGINAL',
      trip_fare: '100.00',
      rider_amount: '85.00',
      company_commission_amount: '15.00',
      operational_cost_amount: '7.50',
      profit_amount: '7.50',
      rider_percentage: '85.00',
      company_commission_percentage: '15.00',
      operational_cost_percentage_of_commission: '50.00',
      payment_settings_version_id: 'v1',
      frozen_at: new Date('2026-10-03T00:00:00.000Z'),
    };
    const finance = {
      findOriginal: jest.fn(async () => existing),
      insertOriginalFromFareSnapshot: jest.fn(),
      findActiveSettings: jest.fn(),
    };
    const fares = {
      findSnapshotByOrder: jest.fn(async () => ({
        fare_snapshot_id: 'f1',
        order_id: ORDER,
        tax: '0.00',
      })),
    };
    const walletCod = { syncOrderFinance: jest.fn(async () => undefined) };
    const orderTax = {
      findByFinanceSnapshot: jest.fn(async () => ({ id: 't1' })),
      insertForFinanceSnapshot: jest.fn(),
    };
    const service = new FinanceService(
      {} as never,
      {} as never,
      fares as never,
      finance as never,
      walletCod as never,
      {} as never,
      orderTax as never,
      { warn: jest.fn() } as never,
    );

    await service.captureOnDelivered(deliveredOrder(), {} as never);
    expect(finance.insertOriginalFromFareSnapshot).not.toHaveBeenCalled();
    expect(walletCod.syncOrderFinance).toHaveBeenCalled();
  });

  it('rejects capture when order is not delivered', async () => {
    const service = new FinanceService(
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      { warn: jest.fn() } as never,
    );
    await expect(
      service.captureOnDelivered(
        { ...deliveredOrder(), canonical_status: 'ASSIGNED' },
        {} as never,
      ),
    ).rejects.toMatchObject({ code: ErrorCodes.INVALID_TRANSITION });
  });
});
