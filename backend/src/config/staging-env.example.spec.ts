import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

describe('backend/.env.staging.example', () => {
  const text = readFileSync(
    resolve(__dirname, '../../.env.staging.example'),
    'utf8',
  );

  it('pins staging isolation and Cashfree sandbox placeholders', () => {
    expect(text).toMatch(/^\s*IU_DEPLOYMENT_TIER=staging\s*$/m);
    expect(text).toMatch(/^\s*CASHFREE_ENVIRONMENT=sandbox\s*$/m);
    expect(text).toMatch(/^\s*PAYMENT_PROVIDER=cashfree\s*$/m);
    expect(text).toContain('<CASHFREE_SANDBOX_CLIENT_ID>');
    expect(text).toContain('<STAGING_RDS_HOST>');
    expect(text).toMatch(
      /^\s*PAYOUT_INSTRUMENT_KEY=<BASE64_32_BYTE_PAYOUT_INSTRUMENT_KEY>\s*$/m,
    );
  });

  it('does not embed production API host or live Cashfree host as defaults', () => {
    expect(text).not.toMatch(/api\.idharudhar\.co\.in/);
    expect(text).not.toMatch(/^\s*CASHFREE_ENVIRONMENT=production\s*$/m);
    expect(text).not.toMatch(/https:\/\/api\.cashfree\.com/);
  });
});
