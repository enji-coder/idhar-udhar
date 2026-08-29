import { Global, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { loadAppConfig } from '../config/configuration';
import { PostgresService } from './postgres.service';

@Global()
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      ignoreEnvFile: true,
      load: [loadAppConfig],
    }),
  ],
  providers: [PostgresService, ConfigService],
  exports: [PostgresService, ConfigService],
})
export class DatabaseModule {}
