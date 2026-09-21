import { Injectable } from '@nestjs/common';
import { AppLogger } from '../common/logger/app-logger';
import { ProfileRole } from '../auth/types/auth-context';
import { DeviceTokensRepository } from './device-tokens.repository';
import {
  buildFcmMulticastMessage,
  isPermanentFcmError,
} from './fcm-message';
import { PushMessage, PushProvider, PushSendResult } from './push-provider';

export type FcmSendResponse = {
  success: boolean;
  messageId?: string;
  error?: { code?: string };
};

export type FcmMulticastResult = {
  successCount: number;
  failureCount: number;
  responses: FcmSendResponse[];
};

export type FcmMessaging = {
  sendEachForMulticast(message: {
    tokens: string[];
    notification: { title: string; body: string };
    data: Record<string, string>;
    android: { priority: 'high' };
  }): Promise<FcmMulticastResult>;
};

export type FcmMessagingFactory = () => FcmMessaging;

const MULTICAST_LIMIT = 500;

@Injectable()
export class FcmPushProvider implements PushProvider {
  readonly mode = 'fcm' as const;
  private messagingFactory: FcmMessagingFactory | null = null;
  private messaging: FcmMessaging | null = null;

  constructor(
    private readonly logger: AppLogger,
    private readonly tokens: DeviceTokensRepository,
  ) {}

  useMessagingFactory(factory: FcmMessagingFactory): void {
    this.messagingFactory = factory;
    this.messaging = null;
  }

  async send(message: PushMessage): Promise<PushSendResult> {
    if (!message.profileType) {
      return {
        ok: false,
        error: 'fcm:missing-profile-type',
        retryable: false,
      };
    }
    const devices = await this.tokens.listActive(
      message.identityId,
      message.profileType as ProfileRole,
    );
    if (devices.length === 0) {
      return {
        ok: false,
        error: 'fcm:no-device-tokens',
        retryable: false,
      };
    }

    const messaging = this.requireMessaging();
    const invalidIds: string[] = [];
    let successCount = 0;
    let transientFailures = 0;
    let providerMessageId: string | null = null;

    try {
      for (let offset = 0; offset < devices.length; offset += MULTICAST_LIMIT) {
        const batch = devices.slice(offset, offset + MULTICAST_LIMIT);
        const payload = buildFcmMulticastMessage(
          message,
          batch.map((row) => row.fcm_token),
        );
        const result = await messaging.sendEachForMulticast(payload);
        successCount += result.successCount;
        result.responses.forEach((response, index) => {
          const device = batch[index];
          if (response.success) {
            if (!providerMessageId && response.messageId) {
              providerMessageId = response.messageId;
            }
            return;
          }
          if (isPermanentFcmError(response.error?.code)) {
            invalidIds.push(device.push_device_token_id);
            return;
          }
          transientFailures += 1;
        });
      }
    } catch (err) {
      this.logger.error('fcm_send_failed', {
        err: err instanceof Error ? err.name : 'unknown',
        delivery_id: message.deliveryId,
        notification_id: message.notificationId,
        token_count: devices.length,
      });
      return {
        ok: false,
        error: 'fcm:unavailable',
        retryable: true,
      };
    }

    if (invalidIds.length > 0) {
      await this.tokens.deactivateByIds(invalidIds);
      this.logger.warn('fcm_tokens_deactivated', {
        delivery_id: message.deliveryId,
        deactivated_count: invalidIds.length,
      });
    }

    if (successCount > 0) {
      return { ok: true, providerMessageId };
    }
    if (transientFailures > 0) {
      return { ok: false, error: 'fcm:unavailable', retryable: true };
    }
    return {
      ok: false,
      error: 'fcm:all-tokens-unregistered',
      retryable: false,
    };
  }

  private requireMessaging(): FcmMessaging {
    if (this.messaging) {
      return this.messaging;
    }
    if (!this.messagingFactory) {
      throw new Error('FCM messaging factory is not configured');
    }
    this.messaging = this.messagingFactory();
    return this.messaging;
  }
}
