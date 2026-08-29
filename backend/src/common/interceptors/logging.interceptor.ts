import {
  CallHandler,
  ExecutionContext,
  HttpException,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Observable, catchError, tap, throwError } from 'rxjs';
import { ApiError } from '../errors/api-error';
import { AppLogger } from '../logger/app-logger';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  constructor(private readonly logger: AppLogger) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const req = http.getRequest<Request>();
    const res = http.getResponse<Response>();
    const started = Date.now();

    const log = (status: number) => {
      this.logger.info('http_request', {
        method: req.method,
        path: req.originalUrl,
        status,
        duration_ms: Date.now() - started,
      });
    };

    return next.handle().pipe(
      tap(() => log(res.statusCode)),
      catchError((err: unknown) => {
        const status =
          err instanceof ApiError
            ? err.status
            : err instanceof HttpException
              ? err.getStatus()
              : 500;
        log(status);
        return throwError(() => err);
      }),
    );
  }
}
