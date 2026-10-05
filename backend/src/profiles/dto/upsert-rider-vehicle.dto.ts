import { Type } from 'class-transformer';
import {
  IsInt,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class UpsertRiderVehicleDto {
  @IsUUID()
  vehicle_category_id!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(20)
  registration!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  model!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(40)
  color!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1980)
  @Max(2100)
  manufacturing_year!: number;
}
