import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../config/configuration';
import { LOCATION_STORE } from './location-store';
import { LocationService } from './location.service';
import { MemoryLocationStore } from './memory-location.store';
import { RiderLocationController } from './rider-location.controller';

@Module({
  controllers: [RiderLocationController],
  providers: [
    MemoryLocationStore,
    LocationService,
    {
      provide: LOCATION_STORE,
      inject: [ConfigService, MemoryLocationStore],
      useFactory: (config: ConfigService, memory: MemoryLocationStore) => {
        config.getOrThrow<AppConfig['location']>('location');
        return memory;
      },
    },
  ],
  exports: [LocationService, LOCATION_STORE, MemoryLocationStore],
})
export class LocationModule {}
