import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { FareRatesDto } from './fare-rates.dto';

export class CreateVehicleCategoryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  code?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  weight_capacity?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  size?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => FareRatesDto)
  rates?: FareRatesDto;
}
