import { ValidationPipe, ValidationError } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { decryptPayoutInstrument } from './payout-instrument-crypto';
import { WalletCodRepository } from './wallet-cod.repository';
import { WalletCodService } from './wallet-cod.service';

const TEST_PAYOUT_INSTRUMENT_KEY = Buffer.alloc(32, 7).toString('base64');
import { SaveBankDto } from './dto/save-bank.dto';
import { SaveUpiDto } from './dto/save-upi.dto';

const riderId = '11111111-1111-4111-8111-111111111111';
const otherRiderId = '22222222-2222-4222-8222-222222222222';
const riderAuth = {
  role: 'RIDER',
  identityId: 'identity-1',
  profileId: riderId,
} as never;

describe('rider payout destinations', () => {
  it('rejects a body that names another rider profile', async () => {
    const pipe = new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      exceptionFactory: (errors: ValidationError[]) =>
        new ApiError(ErrorCodes.VALIDATION_ERROR, 'Request validation failed', 400, errors),
    });
    await expect(
      pipe.transform(
        { vpa: 'name@upi', rider_profile_id: otherRiderId },
        { type: 'body', metatype: SaveUpiDto },
      ),
    ).rejects.toBeInstanceOf(ApiError);
    await expect(
      pipe.transform(
        {
          holder_name: 'Ravi Kumar',
          account_number: '123456789012',
          ifsc: 'HDFC0001234',
          rider_profile_id: otherRiderId,
        },
        { type: 'body', metatype: SaveBankDto },
      ),
    ).rejects.toBeInstanceOf(ApiError);
  });

  it('keeps a single current UPI and bank row for the authenticated rider', async () => {
    const repo = new WalletCodRepository({} as never);
    const store = createDestinationStore();
    await repo.replaceCurrentUpi(riderId, 'n***@upi', 'name@upi', store.db);
    await repo.replaceCurrentUpi(riderId, 'o***@upi', 'other@upi', store.db);
    await repo.replaceCurrentBank(
      riderId,
      {
        holderName: 'Ravi Kumar',
        accountMasked: 'XXXXXX9012',
        accountNumber: '123456789012',
        ifsc: 'HDFC0001234',
      },
      store.db,
    );
    await repo.replaceCurrentBank(
      otherRiderId,
      {
        holderName: 'Other Rider',
        accountMasked: 'XXXXXX1111',
        accountNumber: '999999999111',
        ifsc: 'SBIN0001234',
      },
      store.db,
    );
    expect(store.currentUpis(riderId)).toEqual(['other@upi']);
    expect(store.currentBanks(riderId).map((row) => row.accountNumber)).toEqual([
      '123456789012',
    ]);
    expect(store.currentBanks(otherRiderId).map((row) => row.accountNumber)).toEqual([
      '999999999111',
    ]);
    expect(store.upiOwners()).not.toContain(otherRiderId);
  });

  it('clears only the authenticated rider current UPI and leaves bank and history', async () => {
    const repo = new WalletCodRepository({} as never);
    const store = createDestinationStore();
    await repo.replaceCurrentUpi(riderId, 'o***@upi', 'old@upi', store.db);
    await repo.replaceCurrentUpi(riderId, 'n***@upi', 'name@upi', store.db);
    await repo.replaceCurrentBank(
      riderId,
      {
        holderName: 'Ravi Kumar',
        accountMasked: 'XXXXXX9012',
        accountNumber: '123456789012',
        ifsc: 'HDFC0001234',
      },
      store.db,
    );
    await repo.replaceCurrentUpi(otherRiderId, 'x***@upi', 'other@upi', store.db);

    await expect(repo.clearCurrentUpi(riderId, store.db)).resolves.toBe(true);

    expect(store.currentUpis(riderId)).toEqual([]);
    expect(store.upiRows(riderId).map((row) => row.vpa).sort()).toEqual([
      'name@upi',
      'old@upi',
    ]);
    expect(store.currentBanks(riderId).map((row) => row.accountNumber)).toEqual([
      '123456789012',
    ]);
    expect(store.bankRows(riderId)).toHaveLength(1);
    expect(store.currentUpis(otherRiderId)).toEqual(['other@upi']);
  });

  it('saves a UPI destination and then creates a withdrawal', async () => {
    const harness = makeWithdrawHarness();
    const saved = await harness.service.saveOwnUpi(riderAuth, 'name@upi');
    expect(saved).toEqual({
      rider_upi_id: 'upi-1',
      vpa_masked: 'n***@upi',
      is_current: true,
    });
    expect(JSON.stringify(saved)).not.toContain('name@upi');
    expect(harness.savedUpi?.raw.startsWith('enc1:')).toBe(true);
    expect(
      decryptPayoutInstrument(
        harness.savedUpi?.raw ?? '',
        Buffer.from(TEST_PAYOUT_INSTRUMENT_KEY, 'base64'),
      ),
    ).toBe('name@upi');
    expect(harness.savedUpi?.riderId).toBe(riderId);

    const withdrawal = await harness.service.requestWithdraw(
      riderAuth,
      '10.00',
      'UPI',
      'idem-upi',
    );
    expect(withdrawal.status).toBe('REQUESTED');
    expect(harness.inserts).toBe(1);
    expect(harness.debits).toBe(1);
  });

  it('saves a bank destination and then creates a withdrawal', async () => {
    const harness = makeWithdrawHarness();
    const saved = await harness.service.saveOwnBank(riderAuth, {
      holderName: 'Ravi Kumar',
      accountNumber: '123456789012',
      ifsc: 'hdfc0001234',
    });
    expect(saved.account_masked).toBe('XXXXXX9012');
    expect(saved.is_current).toBe(true);
    expect(JSON.stringify(saved)).not.toContain('123456789012');
    expect(JSON.stringify(saved)).not.toContain('HDFC0001234');
    expect(harness.savedBank?.riderId).toBe(riderId);
    expect(harness.savedBank?.ifsc).toBe('HDFC0001234');

    const withdrawal = await harness.service.requestWithdraw(
      riderAuth,
      '10.00',
      'BANK',
      'idem-bank',
    );
    expect(withdrawal.status).toBe('REQUESTED');
    expect(harness.inserts).toBe(1);
    expect(harness.debits).toBe(1);
  });

  it('uses the current bank for BANK and the current UPI for UPI when both exist', async () => {
    const harness = makeWithdrawHarness();
    await harness.service.saveOwnUpi(riderAuth, 'name@upi');
    await harness.service.saveOwnBank(riderAuth, {
      holderName: 'Ravi Kumar',
      accountNumber: '123456789012',
      ifsc: 'HDFC0001234',
    });

    await harness.service.requestWithdraw(riderAuth, '10.00', 'BANK', 'idem-bank-both');
    expect(harness.lastWithdrawal).toMatchObject({
      payoutMethod: 'BANK',
      riderUpiId: null,
      bankAccountId: 'bank-current',
    });

    await harness.service.requestWithdraw(riderAuth, '5.00', 'UPI', 'idem-upi-both');
    expect(harness.lastWithdrawal).toMatchObject({
      payoutMethod: 'UPI',
      riderUpiId: 'upi-current',
      bankAccountId: null,
    });
    expect(harness.inserts).toBe(2);
  });

  it('returns 409 and does not debit when no destination exists', async () => {
    const harness = makeWithdrawHarness();
    await expect(
      harness.service.requestWithdraw(riderAuth, '10.00', 'UPI', 'idem-missing'),
    ).rejects.toMatchObject({ status: 409 });
    await expect(
      harness.service.requestWithdraw(riderAuth, '10.00', 'BANK', 'idem-missing-bank'),
    ).rejects.toMatchObject({ status: 409 });
    expect(harness.inserts).toBe(0);
    expect(harness.debits).toBe(0);
  });

  it('returns only masked destinations for the authenticated rider', async () => {
    const harness = makeWithdrawHarness();
    await harness.service.saveOwnUpi(riderAuth, 'name@upi');
    await harness.service.saveOwnBank(riderAuth, {
      holderName: 'Ravi Kumar',
      accountNumber: '123456789012',
      ifsc: 'HDFC0001234',
    });
    const view = await harness.service.getOwnDestinations(riderAuth);
    expect(view.upi).toEqual({
      available: true,
      vpa_masked: 'n***@upi',
      status: null,
    });
    expect(view.bank).toMatchObject({
      available: true,
      account_masked: 'XXXXXX9012',
      ifsc: 'HDFC0001234',
    });
    const encoded = JSON.stringify(view);
    expect(encoded).not.toContain('name@upi');
    expect(encoded).not.toContain('123456789012');
    expect(encoded).not.toContain('enc1:');
    const otherAuth = {
      role: 'RIDER' as const,
      identityId: 'identity-2',
      profileId: otherRiderId,
    };
    const other = await harness.service.getOwnDestinations(otherAuth as never);
    expect(other).toEqual({
      upi: { available: false },
      bank: { available: false },
    });
  });
});

function createDestinationStore() {
  const upis: Array<{ riderId: string; vpa: string; current: boolean }> = [];
  const banks: Array<{
    riderId: string;
    accountNumber: string;
    current: boolean;
  }> = [];
  let seq = 0;
  const db = {
    async query(text: string, params: unknown[] = []) {
      const riderIdParam = String(params[0]);
      if (text.includes('FROM rider_profiles')) {
        return { rows: [{ rider_profile_id: riderIdParam }], rowCount: 1 };
      }
      if (text.includes('UPDATE rider_upis')) {
        for (const row of upis) {
          if (row.riderId === riderIdParam) {
            row.current = false;
          }
        }
        return { rows: [], rowCount: 0 };
      }
      if (text.includes('INSERT INTO rider_upis')) {
        if (upis.some((row) => row.riderId === riderIdParam && row.current)) {
          throw new Error('unique current upi');
        }
        upis.push({ riderId: riderIdParam, vpa: String(params[2]), current: true });
        seq += 1;
        return {
          rows: [{ rider_upi_id: `upi-${seq}`, vpa_masked: params[1] }],
          rowCount: 1,
        };
      }
      if (text.includes('UPDATE rider_bank_accounts')) {
        for (const row of banks) {
          if (row.riderId === riderIdParam) {
            row.current = false;
          }
        }
        return { rows: [], rowCount: 0 };
      }
      if (text.includes('INSERT INTO rider_bank_accounts')) {
        if (banks.some((row) => row.riderId === riderIdParam && row.current)) {
          throw new Error('unique current bank');
        }
        banks.push({
          riderId: riderIdParam,
          accountNumber: String(params[3]),
          current: true,
        });
        seq += 1;
        return {
          rows: [{ bank_account_id: `bank-${seq}`, account_masked: params[2] }],
          rowCount: 1,
        };
      }
      throw new Error(`unexpected sql: ${text}`);
    },
  };
  return {
    db: db as never,
    currentUpis: (id: string) =>
      upis.filter((row) => row.riderId === id && row.current).map((row) => row.vpa),
    currentBanks: (id: string) => banks.filter((row) => row.riderId === id && row.current),
    upiOwners: () => upis.map((row) => row.riderId),
    upiRows: (id: string) => upis.filter((row) => row.riderId === id),
    bankRows: (id: string) => banks.filter((row) => row.riderId === id),
  };
}

function makeWithdrawHarness() {
  const state: {
    savedUpi: { riderId: string; raw: string } | null;
    savedBank: { riderId: string; ifsc: string; account: string } | null;
    inserts: number;
    debits: number;
    lastWithdrawal: Record<string, unknown> | null;
  } = {
    savedUpi: null,
    savedBank: null,
    inserts: 0,
    debits: 0,
    lastWithdrawal: null,
  };
  const repo = {
    replaceCurrentUpi: jest.fn(async (profileId: string, _masked: string, vpa: string) => {
      state.savedUpi = { riderId: profileId, raw: vpa };
      return { rider_upi_id: 'upi-1', vpa_masked: 'n***@upi' };
    }),
    replaceCurrentBank: jest.fn(
      async (
        profileId: string,
        input: { ifsc: string; accountMasked: string; accountNumber: string },
      ) => {
        state.savedBank = {
          riderId: profileId,
          ifsc: input.ifsc,
          account: input.accountNumber,
        };
        return { bank_account_id: 'bank-1', account_masked: input.accountMasked };
      },
    ),
    findCurrentUpi: jest.fn(async (profileId: string) => {
      if (!state.savedUpi || state.savedUpi.riderId !== profileId) {
        return null;
      }
      return {
        rider_upi_id: 'upi-current',
        vpa_encrypted_or_token: state.savedUpi.raw,
        vpa_masked: 'n***@upi',
      };
    }),
    findCurrentBankAccount: jest.fn(async (profileId: string) => {
      if (!state.savedBank || state.savedBank.riderId !== profileId) {
        return null;
      }
      return {
        bank_account_id: 'bank-current',
        account_encrypted_or_token: state.savedBank.account,
        account_masked: 'XXXXXX9012',
        ifsc_or_bank: state.savedBank.ifsc,
        holder_name: 'Ravi Kumar',
      };
    }),
    lockAccounts: jest.fn(async () => ({
      wallet: { wallet_account_id: 'wallet-1', available_balance: '50.00' },
      cod: { cod_account_id: 'cod-1', cod_due: '0.00' },
      threshold: '100.00',
    })),
    exceeds: jest.fn(async () => false),
    debitWallet: jest.fn(async () => {
      state.debits += 1;
      return '40.00';
    }),
    insertWalletLedger: jest.fn(async () => ({ wallet_ledger_id: 'ledger-1' })),
    insertWithdrawal: jest.fn(async (input: Record<string, unknown>) => {
      state.inserts += 1;
      state.lastWithdrawal = input;
      return { withdrawal_id: 'withdrawal-1', status: 'REQUESTED' };
    }),
  };
  const service = new WalletCodService(
    { transaction: async (fn: (tx: unknown) => Promise<unknown>) => fn({}) } as never,
    repo as never,
    {
      find: jest.fn(async () => null),
      insert: jest.fn(async () => undefined),
    } as never,
    {
      findRiderDriver: jest.fn(async () => ({ name: 'Ravi Kumar' })),
    } as never,
    { onWithdrawalRequested: jest.fn(async () => undefined) } as never,
    {} as never,
    {
      getOrThrow: () => ({
        provider: 'cashfree',
        payoutInstrumentKey: TEST_PAYOUT_INSTRUMENT_KEY,
      }),
    } as never,
    {} as never,
    { warn: jest.fn(), info: jest.fn() } as never,
  );
  return {
    service,
    get savedUpi() {
      return state.savedUpi;
    },
    get savedBank() {
      return state.savedBank;
    },
    get inserts() {
      return state.inserts;
    },
    get debits() {
      return state.debits;
    },
    get lastWithdrawal() {
      return state.lastWithdrawal;
    },
  };
}
