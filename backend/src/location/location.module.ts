import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../config/configuration';
import { LOCATION_STORE } from './location-store';
import { LocationService } from './location.service';
import { MemoryLocationStore } from './memory-location.store';
import { RedisLocationStore } from './redis-location.store';
import { RiderLocationController } from './rider-location.controller';

@Module({
  controllers: [RiderLocationController],
  providers: [
    MemoryLocationStore,
    RedisLocationStore,
    LocationService,
    {
      provide: LOCATION_STORE,
      inject: [ConfigService, MemoryLocationStore, RedisLocationStore],
      useFactory: (
        config: ConfigService,
        memory: MemoryLocationStore,
        redis: RedisLocationStore,
      ) => {
        const location = config.getOrThrow<AppConfig['location']>('location');
        return location.store === 'redis' ? redis : memory;
      },
    },
  ],
  exports: [
    LocationService,
    LOCATION_STORE,
    MemoryLocationStore,
    RedisLocationStore,
  ],
})
export class LocationModule {}
