import { Global, Module } from '@nestjs/common';
import { APP_FILTER, APP_INTERCEPTOR } from '@nestjs/core';
import { ApiExceptionFilter } from './filters/api-exception.filter';
import { LoggingInterceptor } from './interceptors/logging.interceptor';
import { AppLogger } from './logger/app-logger';

@Global()
@Module({
  providers: [
    AppLogger,
    { provide: APP_FILTER, useClass: ApiExceptionFilter },
    { provide: APP_INTERCEPTOR, useClass: LoggingInterceptor },
  ],
  exports: [AppLogger],
})
export class CommonModule {}
