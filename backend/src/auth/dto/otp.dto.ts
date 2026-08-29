import { IsIn, IsNotEmpty, IsString, Matches } from 'class-validator';

export class OtpRequestDto {
  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsString()
  @IsIn(['CUSTOMER', 'RIDER'])
  actor_type!: 'CUSTOMER' | 'RIDER';
}

export class OtpVerifyDto {
  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsString()
  @IsIn(['CUSTOMER', 'RIDER'])
  actor_type!: 'CUSTOMER' | 'RIDER';

  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{4,8}$/)
  code!: string;
}
