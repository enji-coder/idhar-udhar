import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { ORDER_STATUSES } from '../order-status';

export class TransitionOrderDto {
  @IsIn([...ORDER_STATUSES])
  to_status!: (typeof ORDER_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
