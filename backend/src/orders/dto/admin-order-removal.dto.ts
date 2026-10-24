import { IsString, MaxLength, MinLength } from 'class-validator';

export class AdminOrderRemovalDto {
  @IsString()
  @MinLength(8)
  @MaxLength(500)
  reason!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(40)
  confirm_display_id!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(48)
  confirm_crn!: string;
}
