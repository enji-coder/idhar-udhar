import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseFirebaseServiceAccountJson } from './firebase-credentials';

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
    sslRootCert: string | null;
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
    delivery: 'capture' | 'unconfigured' | 'msg91';
    /**
     * DEVELOPMENT ONLY. When true, loopback may read the in-memory capture
     * code so Chrome can complete OTP. Always false in production.
     * Never log the code. Never enable on a public host.
     */
    httpPeek: boolean;
    /**
     * MSG91 SendOTP. Required only when delivery is msg91.
     * Auth key never falls back to capture/unconfigured.
     */
    msg91: {
      authKey: string | null;
      templateId: string | null;
      senderId: string | null;
      timeoutMs: number;
    };
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
    pushProvider: 'capture' | 'unconfigured' | 'fcm';
  };
  routing: {
    /**
     * Provider selection is an engineering switch.
     * Unset defaults to mock outside production and google in production.
     * google without GOOGLE_MAPS_API_KEY fails at startup — never falls back to mock.
     */
    provider: 'mock' | 'google';
    googleApiKey: string | null;
    timeoutMs: number;
  };
  payment: {
    /**
     * Online adapter. Only `unconfigured` exists: record an ONLINE intent,
     * never mark PAID, never call a gateway. Unknown values fail startup
     * so production cannot silently assume Razorpay/Cashfree/Stripe/sandbox.
     */
    provider: 'unconfigured';
  };
  location: {
    /**
     * Redis/Valkey is the hot last-GPS store (Master §39).
     * Unset defaults to memory outside production and redis in production.
     * redis requires REDIS_ENABLED=true and REDIS_HOST and never falls back to memory.
     */
    store: 'memory' | 'redis';
  };
  redis: {
    enabled: boolean;
    host: string | null;
    port: number;
    tls: boolean;
  };
  /**
   * Private object storage for rider KYC and POD bytes.
   * Metadata stays in PostgreSQL (`stored_files`).
   * s3 uses the default AWS credential provider chain (ECS task role).
   * Never configure static access keys in this process.
   */
  storage: {
    provider: 'unconfigured' | 's3';
    bucket: string | null;
    region: string | null;
    signedUrlTtlSeconds: number;
  };
};

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function booleanFlag(name: string, fallback: boolean): boolean {
  const raw = process.env[name]?.trim().toLowerCase();
  if (!raw) {
    return fallback;
  }
  if (raw === 'true') {
    return true;
  }
  if (raw === 'false') {
    return false;
  }
  throw new Error(`Invalid boolean environment variable: ${name}`);
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
  // Capture (in-memory OTP) cannot be enabled in production even if env says so.
  // msg91 is the production SMS vendor and is allowed when explicitly selected.
  const delivery: 'capture' | 'unconfigured' | 'msg91' =
    deliveryRaw === 'msg91'
      ? 'msg91'
      : nodeEnv === 'production'
        ? 'unconfigured'
        : deliveryRaw === 'unconfigured'
          ? 'unconfigured'
          : 'capture';

  const msg91AuthKey = (process.env.MSG91_AUTHKEY ?? '').trim() || null;
  const msg91TemplateId = (process.env.MSG91_TEMPLATE_ID ?? '').trim() || null;
  const msg91SenderId = (process.env.MSG91_SENDER_ID ?? '').trim() || null;
  if (delivery === 'msg91') {
    if (!msg91AuthKey) {
      throw new Error(
        'OTP_DELIVERY_PROVIDER=msg91 requires MSG91_AUTHKEY; refusing to fall back to capture or unconfigured',
      );
    }
    if (!msg91TemplateId) {
      throw new Error(
        'OTP_DELIVERY_PROVIDER=msg91 requires MSG91_TEMPLATE_ID; refusing to fall back to capture or unconfigured',
      );
    }
    if (!msg91SenderId) {
      throw new Error(
        'OTP_DELIVERY_PROVIDER=msg91 requires MSG91_SENDER_ID; refusing to fall back to capture or unconfigured',
      );
    }
  }

  const pushRaw = (process.env.PUSH_PROVIDER ?? '').toLowerCase();
  // Capture (in-memory fake SENT) cannot be enabled in production even if env says so.
  // fcm is the production push vendor and is allowed when explicitly selected.
  const pushProvider: 'capture' | 'unconfigured' | 'fcm' =
    pushRaw === 'fcm'
      ? 'fcm'
      : nodeEnv === 'production'
        ? 'unconfigured'
        : pushRaw === 'unconfigured'
          ? 'unconfigured'
          : 'capture';
  if (pushProvider === 'fcm') {
    parseFirebaseServiceAccountJson(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }

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

  const otpLength = integer('OTP_LENGTH', 4);
  if (otpLength < 4 || otpLength > 8) {
    throw new Error('OTP_LENGTH engineering bound is 4–8 until business policy is set');
  }

  const routingRaw = (process.env.ROUTING_PROVIDER ?? '').trim().toLowerCase();
  if (routingRaw && routingRaw !== 'mock' && routingRaw !== 'google') {
    throw new Error('ROUTING_PROVIDER must be mock or google');
  }
  const routingProvider: 'mock' | 'google' =
    routingRaw === 'mock' || routingRaw === 'google'
      ? routingRaw
      : nodeEnv === 'production'
        ? 'google'
        : 'mock';
  const googleApiKeyRaw = (process.env.GOOGLE_MAPS_API_KEY ?? '').trim();
  const googleApiKey = googleApiKeyRaw.length > 0 ? googleApiKeyRaw : null;
  if (routingProvider === 'google' && !googleApiKey) {
    throw new Error(
      'ROUTING_PROVIDER=google requires GOOGLE_MAPS_API_KEY; refusing to fall back to mock',
    );
  }

  const paymentRaw = (process.env.PAYMENT_PROVIDER ?? 'unconfigured')
    .trim()
    .toLowerCase();
  if (paymentRaw !== 'unconfigured') {
    throw new Error(
      'PAYMENT_PROVIDER must be unconfigured; no online payment vendor is implemented (refusing sandbox, mock capture, or an unnamed gateway)',
    );
  }
  const paymentProvider = 'unconfigured' as const;

  const redisEnabled = booleanFlag('REDIS_ENABLED', false);
  const redisHost = (process.env.REDIS_HOST ?? '').trim() || null;
  const redisTls = booleanFlag('REDIS_TLS', redisEnabled);
  if (redisEnabled && !redisHost) {
    throw new Error(
      'REDIS_ENABLED=true requires REDIS_HOST; refusing to start without Redis',
    );
  }

  const locationStoreRaw = (process.env.LOCATION_STORE ?? '').trim().toLowerCase();
  if (locationStoreRaw && locationStoreRaw !== 'memory' && locationStoreRaw !== 'redis') {
    throw new Error('LOCATION_STORE must be memory or redis');
  }
  const locationStore: 'memory' | 'redis' =
    locationStoreRaw === 'memory' || locationStoreRaw === 'redis'
      ? locationStoreRaw
      : nodeEnv === 'production'
        ? 'redis'
        : 'memory';
  if (locationStore === 'redis' && !redisEnabled) {
    throw new Error(
      'LOCATION_STORE=redis requires REDIS_ENABLED=true; refusing to fall back to memory',
    );
  }
  if (locationStore === 'redis' && !redisHost) {
    throw new Error(
      'LOCATION_STORE=redis requires REDIS_HOST; refusing to fall back to memory',
    );
  }

  const documentsBucket = (process.env.S3_DOCUMENTS_BUCKET ?? '').trim() || null;
  const awsRegion = (process.env.AWS_REGION ?? '').trim() || null;
  const storageProvider: 'unconfigured' | 's3' = documentsBucket ? 's3' : 'unconfigured';
  if (storageProvider === 's3' && !awsRegion) {
    throw new Error(
      'S3_DOCUMENTS_BUCKET requires AWS_REGION; refusing to start without a region',
    );
  }
  const signedUrlTtlSeconds = integer('S3_SIGNED_URL_TTL_SECONDS', 300);
  if (signedUrlTtlSeconds < 60 || signedUrlTtlSeconds > 900) {
    throw new Error('S3_SIGNED_URL_TTL_SECONDS must be between 60 and 900');
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
      sslRootCert: (process.env.DATABASE_SSL_ROOT_CERT ?? '').trim() || null,
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
        (process.env.DEV_OTP_PEEK ?? 'true').toLowerCase() !== 'false',
      msg91: {
        authKey: msg91AuthKey,
        templateId: msg91TemplateId,
        senderId: msg91SenderId,
        timeoutMs: integer('MSG91_TIMEOUT_MS', 10000),
      },
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
    payment: {
      provider: paymentProvider,
    },
    location: {
      store: locationStore,
    },
    redis: {
      enabled: redisEnabled,
      host: redisHost,
      port: integer('REDIS_PORT', 6379),
      tls: redisTls,
    },
    storage: {
      provider: storageProvider,
      bucket: documentsBucket,
      region: awsRegion,
      signedUrlTtlSeconds,
    },
  };
}
