import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import { OBJECT_STORAGE } from './object-storage';
import { S3ObjectStorage } from './s3-object-storage';
import { UnconfiguredObjectStorage } from './unconfigured-object-storage';

@Global()
@Module({
  providers: [
    {
      provide: OBJECT_STORAGE,
      inject: [ConfigService, AppLogger],
      useFactory: (config: ConfigService, logger: AppLogger) => {
        const storage = config.getOrThrow<AppConfig['storage']>('storage');
        if (storage.provider === 's3') {
          if (!storage.bucket || !storage.region) {
            throw new Error(
              'storage.provider=s3 requires S3_DOCUMENTS_BUCKET and AWS_REGION',
            );
          }
          return new S3ObjectStorage(
            {
              bucket: storage.bucket,
              region: storage.region,
              signedUrlTtlSeconds: storage.signedUrlTtlSeconds,
            },
            logger,
          );
        }
        return new UnconfiguredObjectStorage();
      },
    },
  ],
  exports: [OBJECT_STORAGE],
})
export class StorageModule {}
