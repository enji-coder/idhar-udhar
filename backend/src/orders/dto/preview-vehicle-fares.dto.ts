import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, Matches, ValidateNested } from 'class-validator';
import { UUID_RE } from '../../common/uuid-param.pipe';
import { CreateOrderStopDto } from './create-order.dto';

/**
 * Route-only body. Distance and fare amounts are not accepted.
 * The server routes the stops and prices each active vehicle from its fare version.
 */
export class PreviewVehicleFaresDto {
  @Matches(UUID_RE)
  city_id!: string;

  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(4)
  @ValidateNested({ each: true })
  @Type(() => CreateOrderStopDto)
  stops!: CreateOrderStopDto[];
}
