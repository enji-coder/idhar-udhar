import { IsBoolean, IsIn, IsOptional, Matches, MaxLength, MinLength, IsString } from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class CreateVehicleDto {
  @Matches(UUID_RE)
  vehicle_category_id!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(32)
  registration!: string;

  @IsOptional()
  @Matches(UUID_RE)
  rider_profile_id?: string;

  @IsOptional()
  @IsIn(['BIKE', 'SCOOTER'])
  two_wheeler_subtype?: 'BIKE' | 'SCOOTER' | null;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
