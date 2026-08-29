import { Matches } from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';

export class AssignOrderDto {
  @Matches(UUID_RE)
  rider_profile_id!: string;
}
