import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class UpdateZoneDto {
  @IsOptional()
  @Matches(UUID_RE)
  city_id?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
