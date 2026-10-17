import { Matches } from 'class-validator';

const PERCENT_RE = /^(?:\d{1,3})(?:\.\d{1,2})?$/;

export class PublishPaymentSettingsDto {
  @Matches(PERCENT_RE, {
    message: 'rider_percentage must be a percent with up to 2 decimals',
  })
  rider_percentage!: string;

  @Matches(PERCENT_RE, {
    message: 'company_commission_percentage must be a percent with up to 2 decimals',
  })
  company_commission_percentage!: string;

  @Matches(PERCENT_RE, {
    message:
      'operational_cost_percentage_of_commission must be a percent of company commission with up to 2 decimals',
  })
  operational_cost_percentage_of_commission!: string;
}
