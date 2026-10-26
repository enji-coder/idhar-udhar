import { Transform } from 'class-transformer';
import { Matches, MaxLength } from 'class-validator';

export class SaveUpiDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(/^[a-zA-Z0-9._-]{2,}@[a-zA-Z][a-zA-Z0-9.-]{2,}$/, {
    message: 'Enter a valid UPI ID',
  })
  @MaxLength(100)
  vpa!: string;
}
