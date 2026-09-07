import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { postgresSslOption } from './postgres-ssl';

describe('postgresSslOption', () => {
  it('disables TLS when DATABASE_SSL is false', () => {
    expect(
      postgresSslOption({ ssl: false, rootCertPath: '/app/certs/rds-global-bundle.pem' }),
    ).toBe(false);
  });

  it('verifies the peer without a CA when SSL is on and no cert path is set', () => {
    expect(postgresSslOption({ ssl: true, rootCertPath: null })).toEqual({
      rejectUnauthorized: true,
    });
    expect(postgresSslOption({ ssl: true, rootCertPath: '  ' })).toEqual({
      rejectUnauthorized: true,
    });
  });

  it('loads the CA file and keeps rejectUnauthorized true', () => {
    const dir = mkdtempSync(join(tmpdir(), 'iu-ssl-'));
    const path = join(dir, 'rds-global-bundle.pem');
    writeFileSync(path, '-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----\n');
    expect(postgresSslOption({ ssl: true, rootCertPath: path })).toEqual({
      rejectUnauthorized: true,
      ca: '-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----\n',
    });
    rmSync(dir, { recursive: true, force: true });
  });

  it('fails closed when the CA path is set but the file is missing', () => {
    expect(() =>
      postgresSslOption({ ssl: true, rootCertPath: join(tmpdir(), 'missing-rds-ca.pem') }),
    ).toThrow(/DATABASE_SSL_ROOT_CERT file was not found/);
  });
});
