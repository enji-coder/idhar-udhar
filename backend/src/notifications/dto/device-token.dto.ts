import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  @MinLength(32)
  @MaxLength(4096)
  token!: string;

  @IsOptional()
  @IsIn(['ANDROID', 'IOS', 'WEB'])
  platform?: 'ANDROID' | 'IOS' | 'WEB';
}

export class UnregisterDeviceTokenDto {
  @IsString()
  @MinLength(32)
  @MaxLength(4096)
  token!: string;
}
