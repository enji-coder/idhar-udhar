import { IsIn, IsOptional, Matches } from 'class-validator';
import { INR_AMOUNT_RE } from './set-responsibility.dto';

export class CreateTransactionDto {
  @IsIn(['CUSTOMER', 'RECEIVER'])
  payer_type!: 'CUSTOMER' | 'RECEIVER';

  @IsIn(['ONLINE', 'CASH'])
  method!: 'ONLINE' | 'CASH';

  @Matches(INR_AMOUNT_RE, {
    message: 'amount must be a positive INR decimal',
  })
  amount!: string;

  @IsOptional()
  @IsIn(['CHARGE', 'REFUND'])
  direction?: 'CHARGE' | 'REFUND';

  @IsOptional()
  @IsIn(['PENDING', 'FAILED'])
  transaction_status?: 'PENDING' | 'FAILED';
}
