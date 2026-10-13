import { Body, Controller, Get, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { UpdateRiderLocationDto } from './dto/update-rider-location.dto';
import { LocationService } from './location.service';

@Controller('rider')
export class RiderLocationController {
  constructor(private readonly locations: LocationService) {}

  @Roles('RIDER')
  @Post('location')
  @HttpCode(HttpStatus.OK)
  update(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UpdateRiderLocationDto,
  ) {
    return this.locations.updateRiderLocation(auth, body);
  }

  @Roles('RIDER')
  @Get('location')
  getOwn(@CurrentAuth() auth: AuthContext) {
    return this.locations.getOwnLocation(auth);
  }

  /**
   * Lightweight Online presence pulse. Used when GPS cannot be read but the
   * Rider session/foreground service is still alive. Does not mark Offline.
   */
  @Roles('RIDER')
  @Post('presence/heartbeat')
  @HttpCode(HttpStatus.OK)
  heartbeat(@CurrentAuth() auth: AuthContext) {
    return this.locations.heartbeat(auth);
  }
}
