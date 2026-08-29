import { Injectable, LoggerService } from '@nestjs/common';
import { currentRequestId } from '../http/request-context';

type Level = 'debug' | 'info' | 'warn' | 'error';

const SENSITIVE_KEY =
  /^(otp|password|access_token|refresh_token|accessToken|refreshToken|code_hash|password_hash|refresh_token_hash|pepper|secret)$/i;

export function redactFields(
  fields?: Record<string, unknown>,
): Record<string, unknown> | undefined {
  if (!fields) {
    return fields;
  }
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (SENSITIVE_KEY.test(key)) {
      out[key] = '[redacted]';
      continue;
    }
    out[key] = value;
  }
  return out;
}

@Injectable()
export class AppLogger implements LoggerService {
  log(message: string, ...optional: unknown[]): void {
    this.write('info', message, this.fields(optional));
  }

  error(message: string, ...optional: unknown[]): void {
    this.write('error', message, this.fields(optional));
  }

  warn(message: string, ...optional: unknown[]): void {
    this.write('warn', message, this.fields(optional));
  }

  debug?(message: string, ...optional: unknown[]): void {
    this.write('debug', message, this.fields(optional));
  }

  verbose?(message: string, ...optional: unknown[]): void {
    this.write('debug', message, this.fields(optional));
  }

  info(message: string, fields?: Record<string, unknown>): void {
    this.write('info', message, fields);
  }

  private fields(optional: unknown[]): Record<string, unknown> | undefined {
    const last = optional[optional.length - 1];
    if (last && typeof last === 'object' && !Array.isArray(last)) {
      return last as Record<string, unknown>;
    }
    if (typeof last === 'string') {
      return { context: last };
    }
    return undefined;
  }

  private write(
    level: Level,
    msg: string,
    fields?: Record<string, unknown>,
  ): void {
    const line = {
      ts: new Date().toISOString(),
      level,
      msg,
      request_id: currentRequestId(),
      service: 'idhar-udhar-api',
      ...redactFields(fields),
    };
    const json = JSON.stringify(line);
    if (level === 'error') {
      process.stderr.write(`${json}\n`);
      return;
    }
    process.stdout.write(`${json}\n`);
  }
}
