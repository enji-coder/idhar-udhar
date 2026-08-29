import { DatabaseError } from 'pg';

export function asPgError(err: unknown): DatabaseError | null {
  if (!err || typeof err !== 'object') {
    return null;
  }
  const candidate = err as { code?: unknown; constraint?: unknown };
  if (typeof candidate.code !== 'string') {
    return null;
  }
  return err as DatabaseError;
}

export function isUniqueViolation(
  err: unknown,
  constraint?: string,
): boolean {
  const pg = asPgError(err);
  if (!pg || pg.code !== '23505') {
    return false;
  }
  if (!constraint) {
    return true;
  }
  return pg.constraint === constraint;
}

export function isCheckViolation(err: unknown): boolean {
  return asPgError(err)?.code === '23514';
}

export function isForeignKeyViolation(err: unknown): boolean {
  return asPgError(err)?.code === '23503';
}

export function isRestrictViolation(err: unknown): boolean {
  return asPgError(err)?.code === '23001';
}

export function isRaiseException(err: unknown, fragment?: string): boolean {
  const pg = asPgError(err);
  if (!pg || pg.code !== 'P0001') {
    return false;
  }
  if (!fragment) {
    return true;
  }
  return (pg.message ?? '').includes(fragment);
}
