import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class CreateStateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsString()
  @Matches(/^[A-Za-z]{2,5}$/)
  code!: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
