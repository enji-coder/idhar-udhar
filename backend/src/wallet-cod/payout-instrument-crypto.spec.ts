import {
  classifyStoredPayoutInstrument,
  decryptPayoutInstrument,
  encryptPayoutInstrument,
} from './payout-instrument-crypto';
import {
  PAYOUT_INSTRUMENT_TARGETS,
  legacyInstrumentCompareAndSetSql,
  legacyInstrumentPageSql,
  sealLegacyInstrument,
} from './payout-instrument-backfill';

const key = Buffer.alloc(32, 9);
const otherKey = Buffer.alloc(32, 4);

describe('payout instrument encryption', () => {
  it('stores ciphertext that decrypts to the original and hides the raw value', () => {
    const stored = encryptPayoutInstrument('rider@upi', key);
    expect(stored.startsWith('enc1:')).toBe(true);
    expect(stored).not.toContain('rider@upi');
    expect(decryptPayoutInstrument(stored, key)).toBe('rider@upi');
    expect(classifyStoredPayoutInstrument(stored)).toBe('encrypted');
  });

  it('refuses legacy plaintext instead of returning it', () => {
    const legacy = '123456789012';
    expect(classifyStoredPayoutInstrument(legacy)).toBe('legacy_plaintext');
    expect(() => decryptPayoutInstrument(legacy, key)).toThrow(/not encrypted/);
    try {
      decryptPayoutInstrument(legacy, null);
    } catch (err) {
      expect(err).toBeInstanceOf(Error);
      expect((err as Error).message).not.toContain(legacy);
    }
  });

  it('refuses to decrypt an encrypted value without the key', () => {
    const stored = encryptPayoutInstrument('123456789012', key);
    expect(() => decryptPayoutInstrument(stored, null)).toThrow(/key is required/);
  });

  it('fails authentication for a wrong key and for tampered ciphertext', () => {
    const stored = encryptPayoutInstrument('123456789012', key);
    expect(() => decryptPayoutInstrument(stored, otherKey)).toThrow();
    const raw = Buffer.from(stored.slice('enc1:'.length), 'base64');
    raw[raw.length - 1] ^= 0xff;
    const tampered = `enc1:${raw.toString('base64')}`;
    expect(() => decryptPayoutInstrument(tampered, key)).toThrow();
    try {
      decryptPayoutInstrument(stored, otherKey);
    } catch (err) {
      expect((err as Error).message).not.toContain('123456789012');
    }
  });
});

describe('payout instrument backfill plan', () => {
  it('encrypts a legacy value once and leaves an encrypted value unchanged', () => {
    const legacy = 'legacy-instrument';
    const sealed = sealLegacyInstrument(legacy, key);
    expect(sealed?.startsWith('enc1:')).toBe(true);
    expect(sealed).not.toContain(legacy);
    expect(sealLegacyInstrument(sealed, key)).toBe(sealed);
    expect(sealLegacyInstrument('', key)).toBeNull();
    expect(decryptPayoutInstrument(sealed ?? '', key)).toBe(legacy);
  });

  it('pages legacy rows and compare-and-sets without touching withdrawals', () => {
    const upi = legacyInstrumentPageSql(PAYOUT_INSTRUMENT_TARGETS[0]);
    const bank = legacyInstrumentCompareAndSetSql(PAYOUT_INSTRUMENT_TARGETS[1]);
    expect(upi).toContain('rider_upis');
    expect(upi).toContain('vpa_encrypted_or_token');
    expect(upi).toContain("NOT LIKE 'enc1:%'");
    expect(bank).toContain('rider_bank_accounts');
    expect(bank).toContain('account_encrypted_or_token = $2');
    expect(bank).toContain('account_encrypted_or_token = $3');
    expect(`${upi}\n${bank}`).not.toContain('rider_wallet_withdrawals');
  });
});
