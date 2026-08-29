import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { hydrateProcessEnv } from './configuration';

describe('env hydration', () => {
  const original = process.env.IU_HYDRATE_TEST_SECRET;

  afterEach(() => {
    if (original === undefined) {
      delete process.env.IU_HYDRATE_TEST_SECRET;
    } else {
      process.env.IU_HYDRATE_TEST_SECRET = original;
    }
  });

  it('keeps unquoted hash characters in values and trims CRLF', () => {
    const dir = mkdtempSync(join(tmpdir(), 'iu-env-'));
    const path = join(dir, '.env');
    writeFileSync(path, 'IU_HYDRATE_TEST_SECRET=alpha#beta\r\n', 'utf8');
    delete process.env.IU_HYDRATE_TEST_SECRET;
    hydrateProcessEnv([path]);
    expect(process.env.IU_HYDRATE_TEST_SECRET).toBe('alpha#beta');
    rmSync(dir, { recursive: true, force: true });
  });
});
