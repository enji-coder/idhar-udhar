import { Injectable } from '@nestjs/common';
import { AppLogger } from '../../common/logger/app-logger';
import { maskPhone } from '../phone';
import { OtpDeliveryInput, OtpDeliveryProvider } from './otp-delivery';

/**
 * Honest production default until an SMS vendor is chosen.
 * The challenge is still stored; no SMS is sent; the code is discarded.
 */
@Injectable()
export class UnconfiguredOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly mode = 'unconfigured' as const;

  constructor(private readonly logger: AppLogger) {}

  async send(input: OtpDeliveryInput): Promise<void> {
    void input.code;
    this.logger.warn('otp_delivery_unconfigured', {
      phone_suffix: maskPhone(input.phoneNormalized),
    });
  }
}
