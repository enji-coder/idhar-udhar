import { QueryResult, QueryResultRow } from 'pg';
import { Queryable } from '../database/queryable';
import { ErrorCodes } from '../common/errors/error-codes';
import { FinanceRepository, serializePaymentSettings } from './finance.repository';
import {
  PaymentSettingsService,
  validatePaymentSplit,
} from './payment-settings.service';

type QueryCall = { sql: string; params: unknown[] };

class ScriptedDb implements Queryable {
  readonly calls: QueryCall[] = [];

  constructor(private readonly rowsFor: (sql: string) => unknown[]) {}

  async query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params: unknown[] = [],
  ): Promise<QueryResult<T>> {
    this.calls.push({ sql, params });
    return { rows: this.rowsFor(sql) as T[] } as QueryResult<T>;
  }
}

const PUBLISHED = {
  payment_settings_version_id: '11111111-1111-4111-8111-111111111111',
  version: 2,
  status: 'ACTIVE',
  rider_percentage: '80.00',
  company_commission_percentage: '20.00',
  operational_cost_percentage_of_commission: '40.00',
};

const SPLIT = {
  rider_percentage: '80',
  company_commission_percentage: '20',
  operational_cost_percentage_of_commission: '40',
};

function financeAdmin() {
  return {
    role: 'ADMIN' as const,
    identityId: 'identity-1',
    profileId: 'admin-1',
    sessionId: 'session-1',
  };
}

describe('payment settings activation', () => {
  it('returns no active settings when only inactive versions exist', async () => {
    const db = new ScriptedDb(() => []);
    const repo = new FinanceRepository({} as never);
    await expect(repo.findActiveSettings(db)).resolves.toBeNull();
    expect(db.calls[0].sql).toContain("status = 'ACTIVE'");
    expect(db.calls[0].sql).not.toContain('DRAFT');
    expect(db.calls[0].sql).not.toContain('SUPERSEDED');
  });

  it('publishes the admin split, supersedes the previous ACTIVE row, then activates', async () => {
    const db = new ScriptedDb((sql) => {
      if (sql.includes('FOR UPDATE')) {
        return [{ payment_settings_version_id: 'old-active' }];
      }
      if (sql.includes('MAX(version)')) {
        return [{ version: '3' }];
      }
      if (sql.includes('INSERT INTO payment_settings_versions')) {
        return [{ payment_settings_version_id: PUBLISHED.payment_settings_version_id }];
      }
      if (sql.includes("SET status = 'ACTIVE'")) {
        return [PUBLISHED];
      }
      return [];
    });
    const repo = new FinanceRepository({} as never);
    const row = await repo.publishVersion(
      'admin-1',
      {
        riderPercentage: '80.00',
        companyCommissionPercentage: '20.00',
        operationalCostPercentageOfCommission: '40.00',
      },
      db,
    );

    expect(row).toEqual(PUBLISHED);
    expect(db.calls[0].sql).toContain(
      'LOCK TABLE payment_settings_versions IN SHARE ROW EXCLUSIVE MODE',
    );
    expect(db.calls.some((call) => /\bBEGIN\b|\bCOMMIT\b/.test(call.sql))).toBe(false);
    const insert = db.calls.find((call) =>
      call.sql.includes('INSERT INTO payment_settings_versions'),
    );
    expect(insert?.params).toEqual([4, '80.00', '20.00', '40.00', 'admin-1']);
    expect(insert?.sql).not.toContain('85, 15, 50');
    const supersede = db.calls.findIndex((call) =>
      call.sql.includes("status = 'SUPERSEDED'"),
    );
    const activate = db.calls.findIndex((call) =>
      call.sql.includes("SET status = 'ACTIVE'"),
    );
    expect(supersede).toBeGreaterThan(-1);
    expect(activate).toBeGreaterThan(supersede);
    expect(db.calls.some((call) => /UPDATE order_finance_snapshots/i.test(call.sql))).toBe(
      false,
    );
  });

  it('uses the active version for a new finance freeze and leaves snapshot rows untouched', async () => {
    const db = new ScriptedDb((sql) => {
      if (sql.includes('INSERT INTO order_finance_snapshots')) {
        return [
          {
            finance_snapshot_id: 'snap-1',
            order_id: 'order-1',
            snapshot_kind: 'ORIGINAL',
            trip_fare: '100.00',
            rider_percentage: '80.00',
            company_commission_percentage: '20.00',
            operational_cost_percentage_of_commission: '40.00',
            rider_amount: '80.00',
            company_commission_amount: '20.00',
            operational_cost_amount: '8.00',
            profit_amount: '12.00',
            payment_settings_version_id: PUBLISHED.payment_settings_version_id,
            frozen_at: new Date('2026-10-17T00:00:00.000Z'),
          },
        ];
      }
      if (sql.includes('FROM payment_settings_versions')) {
        return [PUBLISHED];
      }
      return [];
    });
    const repo = new FinanceRepository({} as never);
    const frozen = await repo.insertOriginalFromFareSnapshot('order-1', db);
    const allocation = await repo.allocate('100.00', db);

    expect(frozen?.rider_percentage).toBe('80.00');
    expect(frozen?.company_commission_percentage).toBe('20.00');
    expect(frozen?.operational_cost_percentage_of_commission).toBe('40.00');
    expect(allocation?.rider_percentage).toBe('80.00');
    const freezeSql = db.calls[0].sql;
    expect(freezeSql).toContain('v.rider_percentage');
    expect(freezeSql).toContain('v.company_commission_percentage');
    expect(freezeSql).toContain('v.operational_cost_percentage_of_commission');
    expect(freezeSql).toContain("v.status = 'ACTIVE'");
    expect(freezeSql).toContain('f.trip_fare');
    expect(freezeSql).not.toContain('f.rider_percentage');
    expect(db.calls[1].sql).toContain("WHERE v.status = 'ACTIVE'");
    expect(db.calls.some((call) => /UPDATE order_finance_snapshots/i.test(call.sql))).toBe(
      false,
    );
  });

  it('lets a finance admin read and publish a changed split', async () => {
    const finance = {
      findActiveSettings: jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(PUBLISHED),
      publishVersion: jest.fn(async () => PUBLISHED),
    };
    const identities = {
      findAdminProfile: jest.fn(async () => ({
        admin_profile_id: 'admin-1',
        role: 'FINANCE',
        finance_access: true,
      })),
    };
    const audit = { record: jest.fn(async () => undefined) };
    const postgres = {
      transaction: jest.fn(async (work: (tx: unknown) => Promise<unknown>) => work({})),
    };
    const service = new PaymentSettingsService(
      postgres as never,
      finance as never,
      identities as never,
      audit as never,
    );

    await expect(service.get(financeAdmin())).resolves.toEqual({ active: null });
    const result = await service.publish(financeAdmin(), SPLIT);
    expect(result.payment_settings).toEqual({
      payment_settings_version_id: PUBLISHED.payment_settings_version_id,
      version: 2,
      status: 'ACTIVE',
      rider_percentage: 80,
      company_commission_percentage: 20,
      operational_cost_percentage_of_commission: 40,
    });
    expect(finance.publishVersion).toHaveBeenCalledWith(
      'admin-1',
      {
        riderPercentage: '80.00',
        companyCommissionPercentage: '20.00',
        operationalCostPercentageOfCommission: '40.00',
      },
      expect.anything(),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'PAYMENT_SETTINGS_PUBLISHED',
        entityId: PUBLISHED.payment_settings_version_id,
      }),
    );

    await expect(service.get(financeAdmin())).resolves.toEqual({
      active: expect.objectContaining({
        status: 'ACTIVE',
        rider_percentage: 80,
        company_commission_percentage: 20,
      }),
    });
  });

  it('returns an active 85/15/50 record as percentages, not currency strings', () => {
    const body = serializePaymentSettings({
      payment_settings_version_id: '22222222-2222-4222-8222-222222222222',
      version: 1,
      status: 'ACTIVE',
      rider_percentage: '85.00',
      company_commission_percentage: '15.00',
      operational_cost_percentage_of_commission: '50.00',
    });
    expect(body.rider_percentage).toBe(85);
    expect(body.company_commission_percentage).toBe(15);
    expect(body.operational_cost_percentage_of_commission).toBe(50);
    expect(typeof body.rider_percentage).toBe('number');
    expect(typeof body.company_commission_percentage).toBe('number');
    expect(typeof body.operational_cost_percentage_of_commission).toBe('number');
  });

  it('runs insert, supersede, and activate on the one transaction client', async () => {
    const tx = { query: jest.fn() };
    const postgres = {
      transaction: jest.fn(async (work: (client: unknown) => Promise<unknown>) => work(tx)),
    };
    const finance = {
      findActiveSettings: jest.fn(async () => null),
      publishVersion: jest.fn(async () => PUBLISHED),
    };
    const service = new PaymentSettingsService(
      postgres as never,
      finance as never,
      {
        findAdminProfile: jest.fn(async () => ({
          admin_profile_id: 'admin-1',
          role: 'FINANCE',
          finance_access: true,
        })),
      } as never,
      { record: jest.fn(async () => undefined) } as never,
    );
    await service.publish(financeAdmin(), SPLIT);
    expect(postgres.transaction).toHaveBeenCalledTimes(1);
    expect(finance.publishVersion).toHaveBeenCalledWith(
      'admin-1',
      expect.objectContaining({ riderPercentage: '80.00' }),
      tx,
    );
  });

  it('rejects a split that does not add up to 100 and an operational cost outside 0–100', () => {
    expect(() =>
      validatePaymentSplit({
        rider_percentage: '90',
        company_commission_percentage: '15',
        operational_cost_percentage_of_commission: '50',
      }),
    ).toThrow(/add up to 100%/);
    expect(() =>
      validatePaymentSplit({
        rider_percentage: '85',
        company_commission_percentage: '15',
        operational_cost_percentage_of_commission: '150',
      }),
    ).toThrow(/Operational cost must be between 0 and 100/);
    try {
      validatePaymentSplit({
        rider_percentage: '90',
        company_commission_percentage: '15',
        operational_cost_percentage_of_commission: '50',
      });
    } catch (error) {
      expect(error).toMatchObject({
        code: ErrorCodes.VALIDATION_ERROR,
        status: 422,
      });
    }
  });

  it('does not let a finance-flag admin or a non-admin publish settings', async () => {
    const identities = {
      findAdminProfile: jest.fn(async () => ({
        admin_profile_id: 'admin-1',
        role: 'SUPPORT',
        finance_access: true,
      })),
    };
    const finance = { publishVersion: jest.fn(), findActiveSettings: jest.fn() };
    const service = new PaymentSettingsService(
      { transaction: jest.fn() } as never,
      finance as never,
      identities as never,
      { record: jest.fn() } as never,
    );
    await expect(service.publish(financeAdmin(), SPLIT)).rejects.toMatchObject({
      code: ErrorCodes.FORBIDDEN,
      status: 403,
    });
    await expect(
      service.publish(
        { ...financeAdmin(), role: 'CUSTOMER', profileId: 'customer-1' },
        SPLIT,
      ),
    ).rejects.toMatchObject({
      code: ErrorCodes.FORBIDDEN,
      status: 403,
    });
    expect(finance.publishVersion).not.toHaveBeenCalled();
  });
});
