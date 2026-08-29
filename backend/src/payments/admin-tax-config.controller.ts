import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { PublishTaxConfigDto } from './dto/publish-tax-config.dto';
import { TaxConfigService } from './tax-config.service';

@Controller('admin/tax-config')
export class AdminTaxConfigController {
  constructor(private readonly taxConfig: TaxConfigService) {}

  @Roles('ADMIN')
  @Get()
  get(@CurrentAuth() auth: AuthContext) {
    return this.taxConfig.get(auth);
  }

  @Roles('ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  publish(@CurrentAuth() auth: AuthContext, @Body() body: PublishTaxConfigDto) {
    return this.taxConfig.publish(auth, body);
  }
}
