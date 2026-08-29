import { Type } from 'class-transformer';
import {
  IsISO8601,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

export class UpdateRiderLocationDto {
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @IsISO8601()
  timestamp!: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  accuracy_meters?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(360)
  heading?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  speed?: number;
}
