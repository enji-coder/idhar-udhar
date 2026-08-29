import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../config/configuration';
import { CapturingPushProvider } from './capturing-push.provider';
import { NotificationPreferencesController } from './notification-preferences.controller';
import { NotificationService } from './notification.service';
import { NotificationWorkerHealthController } from './notification-worker-health.controller';
import { NotificationWorkerService } from './notification.worker';
import { NotificationsController } from './notifications.controller';
import { NotificationsRepository } from './notifications.repository';
import { OrderNotificationDispatcher } from './order-notification.dispatcher';
import { PaymentNotificationDispatcher } from './payment-notification.dispatcher';
import { PUSH_PROVIDER } from './push-provider';
import { UnconfiguredPushProvider } from './unconfigured-push.provider';
import { WalletNotificationDispatcher } from './wallet-notification.dispatcher';

@Module({
  controllers: [
    NotificationsController,
    NotificationPreferencesController,
    NotificationWorkerHealthController,
  ],
  providers: [
    NotificationsRepository,
    NotificationService,
    NotificationWorkerService,
    OrderNotificationDispatcher,
    PaymentNotificationDispatcher,
    WalletNotificationDispatcher,
    CapturingPushProvider,
    UnconfiguredPushProvider,
    {
      provide: PUSH_PROVIDER,
      inject: [
        ConfigService,
        CapturingPushProvider,
        UnconfiguredPushProvider,
      ],
      useFactory: (
        config: ConfigService,
        capture: CapturingPushProvider,
        unconfigured: UnconfiguredPushProvider,
      ) => {
        const notifications =
          config.getOrThrow<AppConfig['notifications']>('notifications');
        return notifications.pushProvider === 'capture' ? capture : unconfigured;
      },
    },
  ],
  exports: [
    NotificationService,
    NotificationsRepository,
    NotificationWorkerService,
    OrderNotificationDispatcher,
    PaymentNotificationDispatcher,
    WalletNotificationDispatcher,
    CapturingPushProvider,
  ],
})
export class NotificationsModule {}
