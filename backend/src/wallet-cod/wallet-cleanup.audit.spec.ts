import { ApiError } from '../common/errors/api-error';
import { WalletCleanupService } from './wallet-cleanup.service';
import { WalletCodRepository } from './wallet-cod.repository';
import { PostgresService } from '../database/postgres.service';
import { AuditService } from '../audit/audit.service';
import { AuthContext } from '../auth/types/auth-context';

const admin: AuthContext = {
  identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  sessionId: 'session',
  role: 'ADMIN',
  profileId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
};

const ledgerId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

describe('WalletCleanupService audit rollback', () => {
  it('does not keep a reversal when the mandatory audit insert fails', async () => {
    const stored: string[] = [];
    let committed = false;
    const row = {
      wallet_ledger_id: ledgerId,
      wallet_account_id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      direction: 'CREDIT' as const,
      amount: '10.00',
      entry_type: 'ADJUSTMENT' as const,
      related_order_id: null,
      related_payment_transaction_id: null,
      related_cod_ledger_id: null,
      ledger_balance: '10.00',
    };
    const repo = {
      lockWalletLedger: jest.fn(async () => row),
      findWalletReversal: jest.fn(async () => {
        const id = stored.find((item) => item.startsWith('rev:'));
        return id ? { wallet_ledger_id: id.slice(4) } : null;
      }),
      codSourceFor: jest.fn(async () => null),
      insertWalletReversal: jest.fn(async () => {
        stored.push('rev:ffffffff-ffff-4fff-8fff-ffffffffffff');
      }),
      recomputeWalletBalance: jest.fn(async () => undefined),
    };
    const audit = {
      recordRequired: jest.fn(async () => {
        throw new Error('audit insert failed');
      }),
    };
    const postgres = {
      transaction: async (work: (tx: object) => Promise<unknown>) => {
        const snapshot = stored.slice();
        try {
          const result = await work({});
          committed = true;
          return result;
        } catch (err) {
          stored.splice(0, stored.length, ...snapshot);
          committed = false;
          throw err;
        }
      },
    };
    const cleanup = new WalletCleanupService(
      postgres as unknown as PostgresService,
      repo as unknown as WalletCodRepository,
      audit as unknown as AuditService,
    );
    await expect(
      cleanup.apply(admin, {
        ledger_kind: 'RIDER_WALLET',
        ledger_id: ledgerId,
        reason: 'Remove confirmed dummy adjustment',
        confirm: true,
      }),
    ).rejects.toThrow('audit insert failed');
    expect(stored).toEqual([]);
    expect(committed).toBe(false);
  });

  it('returns a conflict when the ledger update deadlocks', async () => {
    const row = {
      wallet_ledger_id: ledgerId,
      wallet_account_id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      direction: 'CREDIT' as const,
      amount: '10.00',
      entry_type: 'ADJUSTMENT' as const,
      related_order_id: null,
      related_payment_transaction_id: null,
      related_cod_ledger_id: null,
      ledger_balance: '10.00',
    };
    const repo = {
      lockWalletLedger: jest.fn(async () => row),
      findWalletReversal: jest.fn(async () => null),
      insertWalletReversal: jest.fn(async () => {
        throw Object.assign(new Error('deadlock detected'), { code: '40P01' });
      }),
      recomputeWalletBalance: jest.fn(async () => undefined),
    };
    const cleanup = new WalletCleanupService(
      { transaction: async (work: (tx: object) => Promise<unknown>) => work({}) } as unknown as PostgresService,
      repo as unknown as WalletCodRepository,
      { recordRequired: jest.fn(async () => undefined) } as unknown as AuditService,
    );
    await expect(
      cleanup.apply(admin, {
        ledger_kind: 'RIDER_WALLET',
        ledger_id: ledgerId,
        reason: 'Remove confirmed dummy adjustment',
        confirm: true,
      }),
    ).rejects.toBeInstanceOf(ApiError);
    expect(repo.recomputeWalletBalance).not.toHaveBeenCalled();
  });
});
