import { Body, Controller, Get, HttpCode, HttpStatus, Put } from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { UpdateCustomerProfileDto } from './dto/update-customer-profile.dto';
import { ProfilesService } from './profiles.service';

@Controller('customer')
export class CustomerProfileController {
  constructor(private readonly profiles: ProfilesService) {}

  @Roles('CUSTOMER')
  @Get('profile')
  getProfile(@CurrentAuth() auth: AuthContext) {
    return this.profiles.customer(auth);
  }

  @Roles('CUSTOMER')
  @Put('profile')
  @HttpCode(HttpStatus.OK)
  updateProfile(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UpdateCustomerProfileDto,
  ) {
    return this.profiles.updateCustomer(auth, {
      displayName: body.display_name,
      email: body.email,
    });
  }
}
