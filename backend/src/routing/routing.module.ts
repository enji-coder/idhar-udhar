import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../config/configuration';
import { GoogleRoutingProvider } from './google-routing.provider';
import { MockRoutingProvider } from './mock-routing.provider';
import { ROUTING_PROVIDER } from './routing-provider';
import { RoutingService } from './routing.service';

@Module({
  providers: [
    MockRoutingProvider,
    GoogleRoutingProvider,
    RoutingService,
    {
      provide: ROUTING_PROVIDER,
      inject: [ConfigService, MockRoutingProvider, GoogleRoutingProvider],
      useFactory: (
        config: ConfigService,
        mock: MockRoutingProvider,
        google: GoogleRoutingProvider,
      ) => {
        const routing = config.getOrThrow<AppConfig['routing']>('routing');
        return routing.provider === 'google' ? google : mock;
      },
    },
  ],
  exports: [
    RoutingService,
    MockRoutingProvider,
    GoogleRoutingProvider,
    ROUTING_PROVIDER,
  ],
})
export class RoutingModule {}
