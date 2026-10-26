import { Transform } from 'class-transformer';
import { Matches, MaxLength, MinLength } from 'class-validator';

export class SaveBankDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(/^[A-Za-z][A-Za-z .'-]{1,79}$/, {
    message: 'Enter the account holder name',
  })
  @MinLength(3)
  @MaxLength(80)
  holder_name!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.replace(/\s+/g, '') : value,
  )
  @Matches(/^\d{9,18}$/, {
    message: 'Enter a valid account number',
  })
  account_number!: string;

  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @Matches(/^[A-Z]{4}0[A-Z0-9]{6}$/, {
    message: 'Enter a valid IFSC',
  })
  ifsc!: string;
}
