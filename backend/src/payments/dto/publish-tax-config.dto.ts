import { IsIn, IsISO8601, IsOptional, Matches, MaxLength } from 'class-validator';
import { GstBasis } from '../gst-math';

const PERCENT_RE = /^(?:\d{1,3})(?:\.\d{1,2})?$/;

export class PublishTaxConfigDto {
  @Matches(PERCENT_RE, {
    message: 'gst_rate must be a percent with up to 2 decimals',
  })
  gst_rate!: string;

  @IsIn(['NONE', 'INCLUSIVE', 'EXCLUSIVE'])
  gst_calculation_basis!: GstBasis;

  /** Defaults to now. Cannot be backdated; see TaxConfigService.publish. */
  @IsOptional()
  @IsISO8601()
  effective_from?: string;

  @IsOptional()
  @MaxLength(500)
  notes?: string;
}
