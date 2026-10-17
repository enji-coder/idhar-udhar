import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { PublishPaymentSettingsDto } from './dto/publish-payment-settings.dto';
import { PaymentSettingsService } from './payment-settings.service';

@Controller('admin/payment-settings')
export class AdminPaymentSettingsController {
  constructor(private readonly settings: PaymentSettingsService) {}

  @Roles('ADMIN')
  @Get()
  get(@CurrentAuth() auth: AuthContext) {
    return this.settings.get(auth);
  }

  @Roles('ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  publish(@CurrentAuth() auth: AuthContext, @Body() body: PublishPaymentSettingsDto) {
    return this.settings.publish(auth, body);
  }
}
