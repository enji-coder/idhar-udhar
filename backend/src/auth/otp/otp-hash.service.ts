import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../../config/configuration';

@Injectable()
export class OtpHashService {
  constructor(private readonly configService: ConfigService) {}

  generateCode(): string {
    const length = this.otp().length;
    let code = '';
    for (let i = 0; i < length; i += 1) {
      code += randomInt(0, 10).toString();
    }
    return code;
  }

  hash(phoneNormalized: string, code: string): string {
    return createHmac('sha256', this.otp().pepper)
      .update(`otp:${phoneNormalized}:${code}`)
      .digest('hex');
  }

  matches(phoneNormalized: string, code: string, storedHash: string): boolean {
    const computed = this.hash(phoneNormalized, code);
    const left = Buffer.from(computed, 'utf8');
    const right = Buffer.from(storedHash, 'utf8');
    if (left.length !== right.length) {
      return false;
    }
    return timingSafeEqual(left, right);
  }

  private otp(): AppConfig['otp'] {
    return this.configService.getOrThrow<AppConfig['otp']>('otp');
  }
}
