import { Injectable } from '@nestjs/common';
import { PushMessage, PushProvider, PushSendResult } from './push-provider';

/**
 * Local/test sink only. Records push attempts in memory.
 * A capture id is not an FCM/vendor delivery confirmation.
 */
@Injectable()
export class CapturingPushProvider implements PushProvider {
  readonly mode = 'capture' as const;
  private readonly captured: PushMessage[] = [];
  private remainingFailures = 0;

  async send(message: PushMessage): Promise<PushSendResult> {
    this.captured.push(message);
    if (this.remainingFailures > 0) {
      this.remainingFailures -= 1;
      return { ok: false, error: 'captured push failure' };
    }
    return { ok: true, providerMessageId: `capture:${message.deliveryId}` };
  }

  peek(): readonly PushMessage[] {
    return this.captured;
  }

  failNext(times = 1): void {
    this.remainingFailures = times;
  }

  clear(): void {
    this.captured.length = 0;
    this.remainingFailures = 0;
  }
}
