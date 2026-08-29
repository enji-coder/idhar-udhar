import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppConfig } from '../config/configuration';
import { AuthService } from './auth.service';
import { OtpRequestDto, OtpVerifyDto } from './dto/otp.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { CapturingOtpDeliveryProvider } from './otp/capturing-otp-delivery.provider';
import { OtpService } from './otp/otp.service';
import { normalizePhone } from './phone';
import { tokenPairResponse } from './token-pair.response';
import { AuthContext } from './types/auth-context';

function isLoopbackAddress(ip: string | undefined): boolean {
  if (!ip) {
    return false;
  }
  return (
    ip === '127.0.0.1' ||
    ip === '::1' ||
    ip === ':ffff:127.0.0.1' ||
    ip === '::ffff:127.0.0.1'
  );
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly otp: OtpService,
    private readonly config: ConfigService,
    private readonly capture: CapturingOtpDeliveryProvider,
  ) {}

  @Public()
  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  async requestOtp(@Body() body: OtpRequestDto, @Req() req: Request) {
    return this.otp.request({
      phone: body.phone,
      actorType: body.actor_type,
      ip: req.ip,
    });
  }

  @Public()
  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  async verifyOtp(@Body() body: OtpVerifyDto) {
    const result = await this.otp.verify({
      phone: body.phone,
      actorType: body.actor_type,
      code: body.code,
    });
    return {
      ...tokenPairResponse(result),
      identity_id: result.identityId,
      profile_id: result.profileId,
    };
  }

  @Public()
  @Post('token/refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() body: RefreshTokenDto) {
    return tokenPairResponse(await this.auth.rotateRefresh(body.refresh_token));
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  async logout(@CurrentAuth() auth: AuthContext) {
    await this.auth.revokeSession(auth.sessionId);
    return { revoked: true };
  }

  @Get('session')
  session(@CurrentAuth() auth: AuthContext) {
    return {
      identity_id: auth.identityId,
      session_id: auth.sessionId,
      role: auth.role,
      profile_id: auth.profileId,
    };
  }

  /**
   * DEVELOPMENT ONLY. Loopback + DEV_OTP_PEEK=true + capture provider.
   * Chrome has no other honest way to read an in-memory capture code.
   * Disabled in production regardless of env flags.
   */
  @Public()
  @Get('dev/otp-capture')
  peekCapturedOtp(@Query('phone') phone: string | undefined, @Req() req: Request) {
    const otp = this.config.getOrThrow<AppConfig['otp']>('otp');
    const nodeEnv = this.config.get<AppConfig['nodeEnv']>('nodeEnv') ?? 'development';
    const ip = req.ip || req.socket?.remoteAddress;
    if (nodeEnv === 'production' || !otp.httpPeek || otp.delivery !== 'capture') {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Not found', 404);
    }
    if (!isLoopbackAddress(ip)) {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'This endpoint is loopback-only', 403);
    }
    if (!phone) {
      throw new ApiError(ErrorCodes.VALIDATION_ERROR, 'phone is required', 400);
    }
    const phoneNormalized = normalizePhone(phone);
    const code = this.capture.peek(phoneNormalized);
    if (!code) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'No captured OTP for this phone', 404);
    }
    return { delivery: 'capture' as const, phone: phoneNormalized, code };
  }

  @Roles('ADMIN')
  @Get('admin-ping')
  adminPing() {
    return { ok: true };
  }
}
