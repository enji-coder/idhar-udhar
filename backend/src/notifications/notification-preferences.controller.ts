import { Body, Controller, Get, HttpCode, HttpStatus, Put } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { UpdateNotificationPreferencesDto } from './dto/update-preferences.dto';
import { NotificationService } from './notification.service';

@Controller('notification-preferences')
export class NotificationPreferencesController {
  constructor(private readonly notifications: NotificationService) {}

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Get()
  get(@CurrentAuth() auth: AuthContext) {
    return this.notifications.getPreferences(auth);
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Put()
  @HttpCode(HttpStatus.OK)
  update(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UpdateNotificationPreferencesDto,
  ) {
    return this.notifications.updatePreferences(auth, body);
  }
}
