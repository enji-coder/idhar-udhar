import { existsSync, readFileSync } from 'node:fs';

export type PostgresSslOption =
  | false
  | { rejectUnauthorized: true; ca?: string };

/**
 * Production RDS requires the Amazon CA (`DATABASE_SSL_ROOT_CERT`).
 * Node's default trust store does not include it, which surfaces as
 * "self-signed certificate in certificate chain".
 * DATABASE_SSL=false keeps local Docker on an unencrypted connection.
 */
export function postgresSslOption(args: {
  ssl: boolean;
  rootCertPath?: string | null;
}): PostgresSslOption {
  if (!args.ssl) {
    return false;
  }
  const path = (args.rootCertPath ?? '').trim();
  if (!path) {
    return { rejectUnauthorized: true };
  }
  if (!existsSync(path)) {
    throw new Error('DATABASE_SSL_ROOT_CERT file was not found');
  }
  return {
    rejectUnauthorized: true,
    ca: readFileSync(path, 'utf8'),
  };
}
