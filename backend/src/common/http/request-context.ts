import { AsyncLocalStorage } from 'node:async_hooks';
import { randomUUID } from 'node:crypto';
import { Request, Response, NextFunction } from 'express';

type Store = { requestId: string };

const storage = new AsyncLocalStorage<Store>();

export function currentRequestId(): string {
  return storage.getStore()?.requestId ?? 'untracked';
}

export function requestIdMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const header = req.header('x-request-id');
  const requestId =
    header && header.trim().length > 0 ? header.trim().slice(0, 128) : randomUUID();
  res.setHeader('x-request-id', requestId);
  storage.run({ requestId }, () => next());
}
