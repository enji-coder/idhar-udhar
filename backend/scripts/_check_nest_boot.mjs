import 'reflect-metadata';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function load(path) {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#') || !t.includes('=')) continue;
    const i = t.indexOf('=');
    const k = t.slice(0, i).trim();
    let v = t.slice(i + 1).trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    if (process.env[k] === undefined) process.env[k] = v;
  }
}

load(resolve(process.cwd(), '.env'));
process.env.NODE_ENV ??= 'test';
process.env.OTP_DELIVERY_PROVIDER = 'capture';
process.env.PUSH_PROVIDER = 'capture';
process.env.PAYMENT_PROVIDER = 'unconfigured';
process.env.LOCATION_STORE = 'memory';
process.env.REDIS_ENABLED = 'false';
process.env.NOTIFICATION_WORKER_ENABLED = 'false';
process.env.ROUTING_PROVIDER = 'mock';
process.env.JWT_ACCESS_SECRET ??= 'test-jwt-access-secret-min-32-chars!!';
process.env.REFRESH_TOKEN_PEPPER ??= 'test-refresh-pepper-min-32-chars!!';
process.env.OTP_HASH_PEPPER ??= 'test-otp-hash-pepper-min-32-characters!';

const { Test } = await import('@nestjs/testing');
const { AppModule } = await import('../dist/app.module.js').catch(async () => {
  // Prefer compiled if present; otherwise compile via ts-node/register path used by jest.
  await import('ts-node/register/transpile-only');
  return import('../src/app.module.ts');
});

const moduleRef = await Test.createTestingModule({
  imports: [AppModule],
}).compile();
const app = moduleRef.createNestApplication({ rawBody: true });
await app.init();
console.log(JSON.stringify({ nest_boot: 'ok' }));
await app.close();
