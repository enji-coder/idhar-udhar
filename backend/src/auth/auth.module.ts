import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { AppConfig } from '../config/configuration';
import { AdminAuthController } from './admin-auth.controller';
import { AdminAuthService } from './admin-auth.service';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { IdentityRepository } from './identity/identity.repository';
import { CapturingOtpDeliveryProvider } from './otp/capturing-otp-delivery.provider';
import { Msg91OtpDeliveryProvider } from './otp/msg91-otp-delivery.provider';
import { OTP_DELIVERY } from './otp/otp-delivery';
import { OtpHashService } from './otp/otp-hash.service';
import { OtpRepository } from './otp/otp.repository';
import { OtpService } from './otp/otp.service';
import { UnconfiguredOtpDeliveryProvider } from './otp/unconfigured-otp-delivery.provider';
import { PasswordService } from './password.service';
import { SessionRepository } from './session.repository';
import { TokenService } from './token.service';

@Module({
  imports: [JwtModule.register({})],
  controllers: [AuthController, AdminAuthController],
  providers: [
    AuthService,
    AdminAuthService,
    TokenService,
    PasswordService,
    SessionRepository,
    IdentityRepository,
    OtpRepository,
    OtpHashService,
    OtpService,
    CapturingOtpDeliveryProvider,
    UnconfiguredOtpDeliveryProvider,
    Msg91OtpDeliveryProvider,
    {
      provide: OTP_DELIVERY,
      inject: [
        ConfigService,
        CapturingOtpDeliveryProvider,
        UnconfiguredOtpDeliveryProvider,
        Msg91OtpDeliveryProvider,
      ],
      useFactory: (
        config: ConfigService,
        capture: CapturingOtpDeliveryProvider,
        unconfigured: UnconfiguredOtpDeliveryProvider,
        msg91: Msg91OtpDeliveryProvider,
      ) => {
        const otp = config.getOrThrow<AppConfig['otp']>('otp');
        if (otp.delivery === 'capture') {
          return capture;
        }
        if (otp.delivery === 'msg91') {
          return msg91;
        }
        return unconfigured;
      },
    },
    JwtAuthGuard,
    RolesGuard,
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
  exports: [
    AuthService,
    TokenService,
    PasswordService,
    IdentityRepository,
    JwtAuthGuard,
    RolesGuard,
    CapturingOtpDeliveryProvider,
  ],
})
export class AuthModule {}
