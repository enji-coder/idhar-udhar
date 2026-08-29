import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsNotEmpty,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class CreateOrderStopDto {
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(3)
  sequence!: number;

  @IsIn(['PICKUP', 'DROP'])
  stop_type!: 'PICKUP' | 'DROP';

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  address_text!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 6 })
  @Min(-90)
  @Max(90)
  latitude!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 6 })
  @Min(-180)
  @Max(180)
  longitude!: number;

  @IsOptional()
  @Matches(UUID_RE)
  zone_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  contact_name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  contact_phone?: string;
}

export class CreateOrderDto {
  @Matches(UUID_RE)
  city_id!: string;

  @Matches(UUID_RE)
  vehicle_category_id!: string;

  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(4)
  @ValidateNested({ each: true })
  @Type(() => CreateOrderStopDto)
  stops!: CreateOrderStopDto[];
}
