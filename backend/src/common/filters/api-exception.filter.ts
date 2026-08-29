import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { ApiError, ApiErrorBody } from '../errors/api-error';
import { ErrorCodes } from '../errors/error-codes';
import { currentRequestId } from '../http/request-context';
import { AppLogger } from '../logger/app-logger';

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  constructor(private readonly logger: AppLogger) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();
    const requestId = currentRequestId();

    const mapped = this.map(exception);
    this.logger.error('api_error', {
      code: mapped.code,
      status: mapped.status,
      path: req.originalUrl,
      method: req.method,
    });

    const body: ApiErrorBody = {
      error: {
        code: mapped.code,
        message: mapped.message,
        request_id: requestId,
      },
    };
    if (mapped.details !== undefined) {
      body.error.details = mapped.details;
    }
    res.status(mapped.status).json(body);
  }

  private map(exception: unknown): {
    code: string;
    message: string;
    status: number;
    details?: unknown;
  } {
    if (exception instanceof ApiError) {
      return {
        code: exception.code,
        message: exception.message,
        status: exception.status,
        details: exception.details,
      };
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      return {
        code: this.codeForHttp(status),
        message: this.safeHttpMessage(exception),
        status,
      };
    }

    return {
      code: ErrorCodes.INTERNAL_ERROR,
      message: 'An unexpected error occurred',
      status: HttpStatus.INTERNAL_SERVER_ERROR,
    };
  }

  private codeForHttp(status: number): string {
    if (status === 400) return ErrorCodes.VALIDATION_ERROR;
    if (status === 401) return ErrorCodes.UNAUTHENTICATED;
    if (status === 403) return ErrorCodes.FORBIDDEN;
    if (status === 404) return ErrorCodes.NOT_FOUND;
    if (status === 503) return ErrorCodes.DATABASE_UNAVAILABLE;
    return ErrorCodes.INTERNAL_ERROR;
  }

  private safeHttpMessage(exception: HttpException): string {
    const payload = exception.getResponse();
    if (typeof payload === 'string') {
      return payload;
    }
    if (payload && typeof payload === 'object' && 'message' in payload) {
      const message = (payload as { message: unknown }).message;
      if (typeof message === 'string') {
        return message;
      }
    }
    return exception.message || 'Request failed';
  }
}
