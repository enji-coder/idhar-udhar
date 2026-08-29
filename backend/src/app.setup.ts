import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ValidationError } from 'class-validator';
import { NextFunction, Request, Response } from 'express';
import { ApiError } from './common/errors/api-error';
import { ErrorCodes } from './common/errors/error-codes';
import { requestIdMiddleware } from './common/http/request-context';
import { AppLogger } from './common/logger/app-logger';
import { AppConfig } from './config/configuration';

function flattenValidation(
  errors: ValidationError[],
  parent = '',
): { field: string; message: string }[] {
  const details: { field: string; message: string }[] = [];
  for (const error of errors) {
    const field = parent ? `${parent}.${error.property}` : error.property;
    if (error.constraints) {
      for (const message of Object.values(error.constraints)) {
        details.push({ field, message });
      }
    }
    if (error.children && error.children.length > 0) {
      details.push(...flattenValidation(error.children, field));
    }
  }
  return details;
}

function isLoopbackHttpOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    return (
      url.protocol === 'http:' &&
      (url.hostname === 'localhost' ||
        url.hostname === '127.0.0.1' ||
        url.hostname === '10.0.2.2')
    );
  } catch {
    return false;
  }
}

export function isAllowedCorsOrigin(
  origin: string | undefined,
  corsOrigin: string[],
  nodeEnv: string,
): boolean {
  if (!origin) {
    return true;
  }
  if (corsOrigin.includes(origin)) {
    return true;
  }
  return nodeEnv !== 'production' && isLoopbackHttpOrigin(origin);
}

export function configureApp(app: INestApplication): void {
  const logger = app.get(AppLogger);
  app.useLogger(logger);
  app.use(requestIdMiddleware);

  const config = app.get(ConfigService);
  const corsOrigin = config.get<AppConfig['corsOrigin']>('corsOrigin') ?? [];
  const nodeEnv = config.get<AppConfig['nodeEnv']>('nodeEnv') ?? 'development';
  app.use((req: Request, res: Response, next: NextFunction) => {
    const origin = typeof req.headers.origin === 'string' ? req.headers.origin : undefined;
    if (
      isAllowedCorsOrigin(origin, corsOrigin, nodeEnv) &&
      req.headers['access-control-request-private-network'] === 'true'
    ) {
      res.setHeader('Access-Control-Allow-Private-Network', 'true');
    }
    next();
  });
  app.enableCors({
    origin: (
      origin: string | undefined,
      callback: (err: Error | null, allow?: boolean) => void,
    ) => {
      callback(null, isAllowedCorsOrigin(origin, corsOrigin, nodeEnv));
    },
    credentials: true,
  });

  app.setGlobalPrefix('v1', {
    exclude: ['health', 'health/live', 'health/db', 'health/worker'],
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      exceptionFactory: (errors: ValidationError[]) =>
        new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Request validation failed',
          400,
          flattenValidation(errors),
        ),
    }),
  );
}
