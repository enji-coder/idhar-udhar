import { Injectable } from '@nestjs/common';
import { OtpDeliveryInput, OtpDeliveryProvider } from './otp-delivery';

/**
 * Local/test delivery only. Holds the last code in process memory so tests
 * can verify without an SMS vendor. HTTP peek is only via GET /v1/auth/dev/otp-capture
 * when DEV_OTP_PEEK=true, capture delivery, non-production, and loopback.
 */
@Injectable()
export class CapturingOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly mode = 'capture' as const;
  private readonly lastByPhone = new Map<string, string>();

  async send(input: OtpDeliveryInput): Promise<void> {
    this.lastByPhone.set(input.phoneNormalized, input.code);
  }

  peek(phoneNormalized: string): string | undefined {
    return this.lastByPhone.get(phoneNormalized);
  }

  clear(): void {
    this.lastByPhone.clear();
  }
}
