import { IsBoolean, IsIn, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class UpdateVehicleDto {
  @IsOptional()
  @Matches(UUID_RE)
  vehicle_category_id?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(32)
  registration?: string;

  @IsOptional()
  @Matches(UUID_RE)
  rider_profile_id?: string | null;

  @IsOptional()
  @IsIn(['BIKE', 'SCOOTER'])
  two_wheeler_subtype?: 'BIKE' | 'SCOOTER' | null;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
