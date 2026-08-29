import { Controller, Get } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { ProfilesService } from './profiles.service';

@Controller('rider')
export class RiderProfileController {
  constructor(private readonly profiles: ProfilesService) {}

  @Roles('RIDER')
  @Get('profile')
  getProfile(@CurrentAuth() auth: AuthContext) {
    return this.profiles.rider(auth);
  }
}
