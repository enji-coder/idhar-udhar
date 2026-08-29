import { IsIn, IsOptional, Matches } from 'class-validator';

export const INR_AMOUNT_RE = /^(?:\d+)(?:\.\d{1,2})?$/;

export class SetResponsibilityDto {
  @IsIn(['CUSTOMER', 'RECEIVER', 'SPLIT'])
  who_pays!: 'CUSTOMER' | 'RECEIVER' | 'SPLIT';

  @IsOptional()
  @Matches(INR_AMOUNT_RE, {
    message: 'customer_responsibility must be a non-negative INR decimal',
  })
  customer_responsibility?: string;

  @IsOptional()
  @Matches(INR_AMOUNT_RE, {
    message: 'receiver_responsibility must be a non-negative INR decimal',
  })
  receiver_responsibility?: string;
}
