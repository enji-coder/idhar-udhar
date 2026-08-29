import { Matches } from 'class-validator';
import { INR_AMOUNT_RE } from '../../payments/dto/set-responsibility.dto';

export class AmountDto {
  @Matches(INR_AMOUNT_RE, {
    message: 'amount must be a positive INR decimal',
  })
  amount!: string;
}
