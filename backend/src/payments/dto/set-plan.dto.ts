import { Matches } from 'class-validator';
import { INR_AMOUNT_RE } from './set-responsibility.dto';

export class SetPlanDto {
  @Matches(INR_AMOUNT_RE, {
    message: 'customer_planned_online must be a non-negative INR decimal',
  })
  customer_planned_online!: string;

  @Matches(INR_AMOUNT_RE, {
    message: 'customer_planned_cash must be a non-negative INR decimal',
  })
  customer_planned_cash!: string;

  @Matches(INR_AMOUNT_RE, {
    message: 'receiver_planned_online must be a non-negative INR decimal',
  })
  receiver_planned_online!: string;

  @Matches(INR_AMOUNT_RE, {
    message: 'receiver_planned_cash must be a non-negative INR decimal',
  })
  receiver_planned_cash!: string;
}
