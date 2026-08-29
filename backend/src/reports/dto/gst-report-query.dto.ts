import {
  IsIn,
  IsInt,
  IsOptional,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ORDER_STATUSES } from '../../orders/order-status';
import { DATE_PRESETS, DatePreset } from '../date-range';

const DATE_ONLY_RE = /^\d{4}-\d{2}-\d{2}$/;

export const GROUP_BY_OPTIONS = ['day', 'month'] as const;

export type GroupBy = (typeof GROUP_BY_OPTIONS)[number];

export class GstReportQueryDto {
  @IsOptional()
  @IsIn(DATE_PRESETS)
  preset?: DatePreset;

  @IsOptional()
  @Matches(DATE_ONLY_RE, { message: 'from must be a YYYY-MM-DD date' })
  from?: string;

  @IsOptional()
  @Matches(DATE_ONLY_RE, { message: 'to must be a YYYY-MM-DD date' })
  to?: string;

  @IsOptional()
  @IsIn(GROUP_BY_OPTIONS)
  group_by?: GroupBy;

  @IsOptional()
  @IsUUID()
  order_id?: string;

  @IsOptional()
  @MaxLength(40)
  display_id?: string;

  @IsOptional()
  @IsUUID()
  customer_profile_id?: string;

  @IsOptional()
  @IsUUID()
  rider_profile_id?: string;

  @IsOptional()
  @IsUUID()
  city_id?: string;

  @IsOptional()
  @IsUUID()
  vehicle_category_id?: string;

  @IsOptional()
  @IsIn(ORDER_STATUSES)
  order_status?: string;

  /**
   * Derived collection status, not a stored column. It filters which orders are
   * listed; it never changes how revenue is allocated.
   */
  @IsOptional()
  @IsIn(['UNPAID', 'PARTIALLY_PAID', 'PAID'])
  payment_status?: 'UNPAID' | 'PARTIALLY_PAID' | 'PAID';

  /**
   * Orders can be paid by both methods, so this matches "has a settled
   * transaction using this method" rather than a single order-level method.
   */
  @IsOptional()
  @IsIn(['ONLINE', 'CASH'])
  payment_method?: 'ONLINE' | 'CASH';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}
