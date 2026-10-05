import {
  IsDateString,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { RIDER_LANGUAGES } from './update-rider-language.dto';

export class UpdateRiderProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @ValidateIf((_, value) => value !== null && value !== '')
  @IsEmail()
  @MaxLength(254)
  email?: string | null;

  @IsOptional()
  @ValidateIf((_, value) => value !== null && value !== '')
  @IsDateString()
  date_of_birth?: string | null;

  @IsOptional()
  @IsIn(RIDER_LANGUAGES)
  preferred_language?: (typeof RIDER_LANGUAGES)[number];

  /**
   * Driving licence collected on the driver-details step.
   * Phone is intentionally absent: forbidNonWhitelisted rejects it.
   */
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(40)
  driving_licence?: string;
}
