import { ErrorCode } from './error-codes';

export class ApiError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly status: number,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export type ApiErrorBody = {
  error: {
    code: string;
    message: string;
    details?: unknown;
    request_id: string;
  };
};
