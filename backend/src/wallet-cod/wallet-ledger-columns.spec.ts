import {
  COD_LEDGER_COLUMNS,
  COD_LEDGER_REVERSAL_COLUMNS,
  WALLET_LEDGER_COLUMNS,
  WALLET_LEDGER_REVERSAL_COLUMNS,
} from './wallet-cod.repository';

describe('ledger column lists', () => {
  it('keeps existing wallet and COD statements on the pre-0032 columns', () => {
    expect(WALLET_LEDGER_COLUMNS).not.toMatch(/reverses_wallet_ledger_id/);
    expect(WALLET_LEDGER_COLUMNS).not.toMatch(/reversal_reason/);
    expect(COD_LEDGER_COLUMNS).not.toMatch(/reverses_cod_ledger_id/);
    expect(COD_LEDGER_COLUMNS).not.toMatch(/reversal_reason/);
  });

  it('adds reversal columns only on the cleanup column lists', () => {
    expect(WALLET_LEDGER_REVERSAL_COLUMNS).toMatch(/reverses_wallet_ledger_id/);
    expect(WALLET_LEDGER_REVERSAL_COLUMNS).toMatch(/reversal_reason/);
    expect(COD_LEDGER_REVERSAL_COLUMNS).toMatch(/reverses_cod_ledger_id/);
    expect(COD_LEDGER_REVERSAL_COLUMNS).toMatch(/reversal_reason/);
  });
});
