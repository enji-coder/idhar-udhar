import {
  IsBoolean,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class UpdateCityDto {
  @IsOptional()
  @Matches(UUID_RE)
  state_id?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2,5}$/)
  city_code?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
