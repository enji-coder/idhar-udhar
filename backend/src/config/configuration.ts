import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export type AppConfig = {
  nodeEnv: string;
  port: number;
  corsOrigin: string[];
  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password: string;
    ssl: boolean;
    poolMax: number;
  };
  jwt: {
    accessSecret: string;
    accessTtlSeconds: number;
    refreshTtlSeconds: number;
    issuer: string;
    refreshPepper: string;
  };
  otp: {
    /**
     * DEVELOPMENT DEFAULTS only. Length, TTL, and max attempts are
     * NEEDS BUSINESS DECISION — not locked product rules.
     * Cooldown 30s is an architecture lock (Master §7.5 / 18 §J).
     */
    length: number;
    ttlSeconds: number;
    maxAttempts: number;
    cooldownSeconds: number;
    maxRequestsPerHour: number;
    pepper: string;
    delivery: 'capture' | 'unconfigured';
    /**
     * DEVELOPMENT ONLY. When true, loopback may read the in-memory capture
     * code so Chrome can complete OTP. Always false in production.
     * Never log the code. Never enable on a public host.
     */
    httpPeek: boolean;
  };
  /**
   * Quote/offer TTLs are DEVELOPMENT DEFAULTS.
   * Production SEARCHING TTL / offer timeout remain NEEDS BUSINESS DECISION.
   */
  fare: {
    quoteTtlSeconds: number;
  };
  dispatch: {
    offerTtlSeconds: number;
  };
  notifications: {
    /**
     * Worker retry ceiling and poll interval are DEVELOPMENT DEFAULTS,
     * not locked product rules.
     */
    workerEnabled: boolean;
    pollMs: number;
    batchSize: number;
    maxAttempts: number;
    retryBackoffSeconds: number;
    pushProvider: 'capture' | 'unconfigured';
  };
  routing: {
    /**
     * Provider selection is an engineering switch.
     * google without GOOGLE_MAPS_API_KEY fails at startup — never falls back to mock.
     */
    provider: 'mock' | 'google';
    googleApiKey: string | null;
    timeoutMs: number;
  };
  location: {
    /**
     * Redis is the architecture direction for hot GPS (Master §39).
     * This phase only implements the in-memory seam. LOCATION_STORE=redis fails clearly.
     */
    store: 'memory';
  };
};

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function integer(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid integer environment variable: ${name}`);
  }
  return parsed;
}

export function envFilePaths(): string[] {
  const cwd = process.cwd();
  // First-wins: backend/.env overrides shared records_database/.env.
  const candidates = [
    resolve(cwd, '.env'),
    resolve(cwd, '..', 'records_database', '.env'),
    resolve(cwd, 'records_database', '.env'),
  ];
  return candidates.filter((path) => existsSync(path));
}

/**
 * Load .env without dotenv comment truncation. Unquoted values may contain `#`
 * (local Postgres passwords). Full-line `#` comments still work. CRLF is trimmed.
 * Existing process.env keys are not overwritten.
 */
export function hydrateProcessEnv(paths: string[] = envFilePaths()): void {
  for (const path of paths) {
    if (!existsSync(path)) {
      continue;
    }
    for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
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
}

hydrateProcessEnv();

export function loadAppConfig(): AppConfig {
  const accessSecret = required('JWT_ACCESS_SECRET');
  const refreshPepper = required('REFRESH_TOKEN_PEPPER');
  if (accessSecret.length < 32) {
    throw new Error('JWT_ACCESS_SECRET must be at least 32 characters');
  }
  if (refreshPepper.length < 32) {
    throw new Error('REFRESH_TOKEN_PEPPER must be at least 32 characters');
  }

  const corsRaw = process.env.CORS_ORIGIN ?? '';
  const corsOrigin = corsRaw
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);

  const nodeEnv = process.env.NODE_ENV ?? 'development';
  const deliveryRaw = (process.env.OTP_DELIVERY_PROVIDER ?? '').toLowerCase();
  const delivery: 'capture' | 'unconfigured' =
    deliveryRaw === 'capture' || deliveryRaw === 'unconfigured'
      ? deliveryRaw
      : nodeEnv === 'production'
        ? 'unconfigured'
        : 'capture';

  const pushRaw = (process.env.PUSH_PROVIDER ?? '').toLowerCase();
  const pushProvider: 'capture' | 'unconfigured' =
    pushRaw === 'capture' || pushRaw === 'unconfigured'
      ? pushRaw
      : nodeEnv === 'production'
        ? 'unconfigured'
        : 'capture';

  const workerEnabledRaw = (process.env.NOTIFICATION_WORKER_ENABLED ?? '').toLowerCase();
  const workerEnabled =
    workerEnabledRaw === 'true'
      ? true
      : workerEnabledRaw === 'false'
        ? false
        : nodeEnv !== 'test';

  const otpPepper = process.env.OTP_HASH_PEPPER || refreshPepper;
  if (otpPepper.length < 32) {
    throw new Error('OTP_HASH_PEPPER (or REFRESH_TOKEN_PEPPER fallback) must be at least 32 characters');
  }

  const otpLength = integer('OTP_LENGTH', 6);
  if (otpLength < 4 || otpLength > 8) {
    throw new Error('OTP_LENGTH engineering bound is 4–8 until business policy is set');
  }

  const routingRaw = (process.env.ROUTING_PROVIDER ?? 'mock').toLowerCase();
  if (routingRaw !== 'mock' && routingRaw !== 'google') {
    throw new Error('ROUTING_PROVIDER must be mock or google');
  }
  const routingProvider: 'mock' | 'google' = routingRaw;
  const googleApiKeyRaw = (process.env.GOOGLE_MAPS_API_KEY ?? '').trim();
  const googleApiKey = googleApiKeyRaw.length > 0 ? googleApiKeyRaw : null;
  if (routingProvider === 'google' && !googleApiKey) {
    throw new Error(
      'ROUTING_PROVIDER=google requires GOOGLE_MAPS_API_KEY; refusing to fall back to mock',
    );
  }

  const locationStoreRaw = (process.env.LOCATION_STORE ?? 'memory').toLowerCase();
  if (locationStoreRaw === 'redis') {
    throw new Error(
      'LOCATION_STORE=redis is not implemented in this phase; use LOCATION_STORE=memory',
    );
  }
  if (locationStoreRaw !== 'memory') {
    throw new Error('LOCATION_STORE must be memory');
  }

  return {
    nodeEnv,
    port: integer('PORT', 3000),
    corsOrigin,
    database: {
      host: required('DATABASE_HOST'),
      port: integer('DATABASE_PORT', 5432),
      name: required('DATABASE_NAME'),
      user: required('DATABASE_USER'),
      password: required('DATABASE_PASSWORD'),
      ssl: (process.env.DATABASE_SSL ?? 'false').toLowerCase() === 'true',
      poolMax: integer('DATABASE_POOL_MAX', 10),
    },
    jwt: {
      accessSecret,
      accessTtlSeconds: integer('JWT_ACCESS_TTL_SECONDS', 900),
      refreshTtlSeconds: integer('JWT_REFRESH_TTL_SECONDS', 2592000),
      issuer: process.env.JWT_ISSUER ?? 'idhar-udhar-api',
      refreshPepper,
    },
    otp: {
      length: otpLength,
      ttlSeconds: integer('OTP_TTL_SECONDS', 300),
      maxAttempts: integer('OTP_MAX_ATTEMPTS', 5),
      cooldownSeconds: integer('OTP_COOLDOWN_SECONDS', 30),
      maxRequestsPerHour: integer('OTP_MAX_REQUESTS_PER_HOUR', 20),
      pepper: otpPepper,
      delivery,
      httpPeek:
        nodeEnv !== 'production' &&
        delivery === 'capture' &&
        (process.env.DEV_OTP_PEEK ?? '').toLowerCase() === 'true',
    },
    fare: {
      quoteTtlSeconds: integer('FARE_QUOTE_TTL_SECONDS', 900),
    },
    dispatch: {
      offerTtlSeconds: integer('OFFER_TTL_SECONDS', 300),
    },
    notifications: {
      workerEnabled,
      pollMs: integer('NOTIFICATION_WORKER_POLL_MS', 5000),
      batchSize: integer('NOTIFICATION_WORKER_BATCH_SIZE', 20),
      maxAttempts: integer('NOTIFICATION_MAX_ATTEMPTS', 5),
      retryBackoffSeconds: integer('NOTIFICATION_RETRY_BACKOFF_SECONDS', 2),
      pushProvider,
    },
    routing: {
      provider: routingProvider,
      googleApiKey,
      timeoutMs: integer('ROUTING_TIMEOUT_MS', 10000),
    },
    location: {
      store: 'memory',
    },
  };
}
