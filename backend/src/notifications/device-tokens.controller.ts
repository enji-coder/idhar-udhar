import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import {
  RegisterDeviceTokenDto,
  UnregisterDeviceTokenDto,
} from './dto/device-token.dto';
import { DeviceTokensService } from './device-tokens.service';

@Controller('device-tokens')
export class DeviceTokensController {
  constructor(private readonly devices: DeviceTokensService) {}

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Post()
  @HttpCode(HttpStatus.OK)
  register(
    @CurrentAuth() auth: AuthContext,
    @Body() body: RegisterDeviceTokenDto,
  ) {
    return this.devices.register(auth, body);
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Post('unregister')
  @HttpCode(HttpStatus.OK)
  unregister(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UnregisterDeviceTokenDto,
  ) {
    return this.devices.unregister(auth, body.token);
  }
}
