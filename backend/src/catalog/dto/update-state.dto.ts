import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class UpdateStateDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z]{2,5}$/)
  code?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
