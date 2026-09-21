import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../config/configuration';
import { CapturingPushProvider } from './capturing-push.provider';
import { DeviceTokensController } from './device-tokens.controller';
import { DeviceTokensRepository } from './device-tokens.repository';
import { DeviceTokensService } from './device-tokens.service';
import { FcmPushProvider } from './fcm-push.provider';
import { createFirebaseMessaging } from './firebase-messaging.factory';
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
    DeviceTokensController,
  ],
  providers: [
    NotificationsRepository,
    NotificationService,
    NotificationWorkerService,
    OrderNotificationDispatcher,
    PaymentNotificationDispatcher,
    WalletNotificationDispatcher,
    DeviceTokensRepository,
    DeviceTokensService,
    CapturingPushProvider,
    UnconfiguredPushProvider,
    FcmPushProvider,
    {
      provide: PUSH_PROVIDER,
      inject: [
        ConfigService,
        CapturingPushProvider,
        UnconfiguredPushProvider,
        FcmPushProvider,
      ],
      useFactory: (
        config: ConfigService,
        capture: CapturingPushProvider,
        unconfigured: UnconfiguredPushProvider,
        fcm: FcmPushProvider,
      ) => {
        const notifications =
          config.getOrThrow<AppConfig['notifications']>('notifications');
        if (notifications.pushProvider === 'capture') {
          return capture;
        }
        if (notifications.pushProvider === 'fcm') {
          fcm.useMessagingFactory(createFirebaseMessaging);
          return fcm;
        }
        return unconfigured;
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
    DeviceTokensService,
  ],
})
export class NotificationsModule {}
