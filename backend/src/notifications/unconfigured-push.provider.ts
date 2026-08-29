import { Injectable } from '@nestjs/common';
import { AppLogger } from '../common/logger/app-logger';
import { PushMessage, PushProvider, PushSendResult } from './push-provider';

/**
 * Honest default until a production push vendor is chosen.
 * Does not pretend a push was delivered.
 */
@Injectable()
export class UnconfiguredPushProvider implements PushProvider {
  readonly mode = 'unconfigured' as const;

  constructor(private readonly logger: AppLogger) {}

  async send(message: PushMessage): Promise<PushSendResult> {
    this.logger.warn('push_provider_unconfigured', {
      delivery_id: message.deliveryId,
      notification_id: message.notificationId,
      channel: 'PUSH',
    });
    return { ok: false, error: 'push provider is not configured' };
  }
}
