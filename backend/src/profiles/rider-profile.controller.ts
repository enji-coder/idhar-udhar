import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  Put,
} from '@nestjs/common';
import { CurrentAuth } from '../common/decorators/current-auth.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthContext } from '../auth/types/auth-context';
import { SetRiderAvailabilityDto } from './dto/set-rider-availability.dto';
import { UpdateRiderLanguageDto } from './dto/update-rider-language.dto';
import { UpdateRiderProfileDto } from './dto/update-rider-profile.dto';
import { UpsertRiderVehicleDto } from './dto/upsert-rider-vehicle.dto';
import { ProfilesService } from './profiles.service';

@Controller('rider')
export class RiderProfileController {
  constructor(private readonly profiles: ProfilesService) {}

  @Roles('RIDER')
  @Get('profile')
  getProfile(@CurrentAuth() auth: AuthContext) {
    return this.profiles.rider(auth);
  }

  @Roles('RIDER')
  @Patch('profile')
  @HttpCode(HttpStatus.OK)
  updateProfile(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UpdateRiderProfileDto,
  ) {
    return this.profiles.updateRider(auth, this.profileInput(body));
  }

  /**
   * PUT alias for environments / proxies that block PATCH.
   * Same body and persistence as PATCH /rider/profile.
   */
  @Roles('RIDER')
  @Put('profile')
  @HttpCode(HttpStatus.OK)
  updateProfilePut(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UpdateRiderProfileDto,
  ) {
    return this.profiles.updateRider(auth, this.profileInput(body));
  }

  @Roles('RIDER')
  @Put('vehicle')
  @HttpCode(HttpStatus.OK)
  upsertVehicle(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UpsertRiderVehicleDto,
  ) {
    return this.profiles.upsertRiderVehicle(auth, {
      vehicleCategoryId: body.vehicle_category_id,
      registration: body.registration,
      model: body.model,
      color: body.color,
      manufacturingYear: body.manufacturing_year,
    });
  }

  private profileInput(body: UpdateRiderProfileDto) {
    return {
      name: body.name,
      email: body.email,
      dateOfBirth: body.date_of_birth,
      preferredLanguage: body.preferred_language,
      drivingLicence: body.driving_licence,
    };
  }

  @Roles('RIDER')
  @Post('availability')
  @HttpCode(HttpStatus.OK)
  setAvailability(
    @CurrentAuth() auth: AuthContext,
    @Body() body: SetRiderAvailabilityDto,
  ) {
    return this.profiles.setRiderAvailability(auth, body.online);
  }

  @Roles('RIDER')
  @Put('profile/language')
  @HttpCode(HttpStatus.OK)
  updateLanguage(
    @CurrentAuth() auth: AuthContext,
    @Body() body: UpdateRiderLanguageDto,
  ) {
    return this.profiles.setRiderLanguage(auth, body.preferred_language);
  }
}
