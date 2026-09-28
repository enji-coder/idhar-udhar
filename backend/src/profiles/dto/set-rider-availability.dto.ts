import { IsBoolean } from 'class-validator';

export class SetRiderAvailabilityDto {
  @IsBoolean()
  online!: boolean;
}
