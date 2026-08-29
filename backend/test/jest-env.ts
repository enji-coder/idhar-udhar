import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function loadDotEnv(path: string): void {
  if (!existsSync(path)) {
    return;
  }
  const text = readFileSync(path, 'utf8');
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }
    const eq = trimmed.indexOf('=');
    if (eq < 1) {
      continue;
    }
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

loadDotEnv(resolve(process.cwd(), '.env'));
loadDotEnv(resolve(process.cwd(), '..', 'records_database', '.env'));
loadDotEnv(resolve(process.cwd(), 'records_database', '.env'));

process.env.NODE_ENV ??= 'test';
process.env.PORT ??= '0';
process.env.JWT_ACCESS_SECRET ??=
  'test-jwt-access-secret-min-32-chars!!';
process.env.REFRESH_TOKEN_PEPPER ??=
  'test-refresh-pepper-min-32-chars!!';
process.env.JWT_ACCESS_TTL_SECONDS ??= '900';
process.env.JWT_REFRESH_TTL_SECONDS ??= '2592000';
process.env.JWT_ISSUER ??= 'idhar-udhar-api';
process.env.DATABASE_HOST ??= 'localhost';
process.env.DATABASE_PORT ??= '5432';
process.env.DATABASE_NAME ??= 'idhar_udhar';
process.env.DATABASE_USER ??= 'idhar_admin';
process.env.DATABASE_SSL ??= 'false';
process.env.DATABASE_POOL_MAX ??= '10';
process.env.OTP_DELIVERY_PROVIDER = 'capture';
process.env.DEV_OTP_PEEK = 'false';
process.env.OTP_COOLDOWN_SECONDS = '0';
process.env.OTP_TTL_SECONDS ??= '300';
process.env.OTP_MAX_ATTEMPTS ??= '5';
process.env.OTP_LENGTH ??= '6';
process.env.OTP_MAX_REQUESTS_PER_HOUR = '100';
process.env.OTP_HASH_PEPPER ??=
  'test-otp-hash-pepper-min-32-characters!';
process.env.FARE_QUOTE_TTL_SECONDS ??= '900';
process.env.OFFER_TTL_SECONDS ??= '300';
process.env.PUSH_PROVIDER = 'capture';
process.env.NOTIFICATION_WORKER_ENABLED = 'false';
process.env.NOTIFICATION_MAX_ATTEMPTS ??= '3';
process.env.NOTIFICATION_RETRY_BACKOFF_SECONDS = '0';
process.env.NOTIFICATION_WORKER_BATCH_SIZE ??= '20';
process.env.ROUTING_PROVIDER = 'mock';
process.env.LOCATION_STORE = 'memory';
process.env.CORS_ORIGIN ??=
  'http://localhost:5173,http://localhost:8888,https://idhar-udhar-admin.netlify.app';
