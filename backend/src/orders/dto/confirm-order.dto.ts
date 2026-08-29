import { Matches } from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class ConfirmOrderDto {
  @Matches(UUID_RE)
  fare_quote_id!: string;
}
