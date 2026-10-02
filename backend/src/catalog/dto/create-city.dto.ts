import {
  IsBoolean,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class CreateCityDto {
  @Matches(UUID_RE)
  state_id!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsString()
  @Matches(/^[A-Za-z]{2,5}$/)
  city_code!: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
