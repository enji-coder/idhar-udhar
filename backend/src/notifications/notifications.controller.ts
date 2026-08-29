import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { UuidParamPipe } from '../common/uuid-param.pipe';
import { AuthContext } from '../auth/types/auth-context';
import { NotificationService } from './notification.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationService) {}

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Get()
  list(
    @CurrentAuth() auth: AuthContext,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    return this.notifications.list(auth, limit, cursor);
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Get('unread-count')
  unreadCount(@CurrentAuth() auth: AuthContext) {
    return this.notifications.unreadCount(auth);
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Post('read-all')
  @HttpCode(HttpStatus.OK)
  markAllRead(@CurrentAuth() auth: AuthContext) {
    return this.notifications.markAllRead(auth);
  }

  @Roles('CUSTOMER', 'RIDER', 'ADMIN')
  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  markRead(
    @CurrentAuth() auth: AuthContext,
    @Param('id', UuidParamPipe) id: string,
  ) {
    return this.notifications.markRead(auth, id);
  }
}
