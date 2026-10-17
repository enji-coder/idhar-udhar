import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { AuditService } from '../audit/audit.service';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { PostgresService } from '../database/postgres.service';
import { formatInr } from '../fare/money';
import { assertAdminFinance, assertTaxConfigWriter } from './admin-finance.acl';
import { PublishPaymentSettingsDto } from './dto/publish-payment-settings.dto';
import {
  FinanceRepository,
  serializePaymentSettings,
} from './finance.repository';

type ValidatedSplit = {
  riderPercentage: string;
  companyCommissionPercentage: string;
  operationalCostPercentageOfCommission: string;
};

function percentCents(raw: string, label: string): { text: string; cents: number } {
  let text: string;
  try {
    text = formatInr(raw);
  } catch {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      `${label} must be a percent with up to 2 decimals`,
      422,
    );
  }
  if (text.startsWith('-')) {
    throw new ApiError(ErrorCodes.VALIDATION_ERROR, `${label} cannot be negative`, 422);
  }
  const cents = Number(text.replace('.', ''));
  if (cents > 10000) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      `${label} must be between 0 and 100`,
      422,
    );
  }
  return { text, cents };
}

/**
 * Rider and company shares of trip fare must sum to 100.
 * Operational cost is a separate percent of the company commission (0–100).
 */
export function validatePaymentSplit(body: PublishPaymentSettingsDto): ValidatedSplit {
  const rider = percentCents(body.rider_percentage, 'Rider share');
  const company = percentCents(body.company_commission_percentage, 'Company commission');
  const operational = percentCents(
    body.operational_cost_percentage_of_commission,
    'Operational cost',
  );
  if (rider.cents + company.cents !== 10000) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'Rider share and company commission must add up to 100%',
      422,
    );
  }
  return {
    riderPercentage: rider.text,
    companyCommissionPercentage: company.text,
    operationalCostPercentageOfCommission: operational.text,
  };
}

@Injectable()
export class PaymentSettingsService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly finance: FinanceRepository,
    private readonly identities: IdentityRepository,
    private readonly audit: AuditService,
  ) {}

  async get(auth: AuthContext) {
    await assertAdminFinance(this.identities, auth);
    const active = await this.finance.findActiveSettings();
    return {
      active: active ? serializePaymentSettings(active) : null,
    };
  }

  /**
   * Inserts the admin-configured split as the next version and activates it.
   * Does not rewrite finance snapshots and does not configure Cashfree.
   */
  async publish(auth: AuthContext, body: PublishPaymentSettingsDto) {
    const profile = await assertTaxConfigWriter(this.identities, auth);
    const split = validatePaymentSplit(body);
    const previous = await this.finance.findActiveSettings();
    const published = await this.postgres.transaction((tx) =>
      this.finance.publishVersion(profile.admin_profile_id, split, tx),
    );
    await this.audit.record({
      auth,
      action: 'PAYMENT_SETTINGS_PUBLISHED',
      entityType: 'PAYMENT_SETTINGS_VERSION',
      entityId: published.payment_settings_version_id,
      category: 'FINANCIAL',
      oldValue: previous
        ? {
            version: previous.version,
            rider_percentage: previous.rider_percentage,
            company_commission_percentage: previous.company_commission_percentage,
            operational_cost_percentage_of_commission:
              previous.operational_cost_percentage_of_commission,
          }
        : null,
      newValue: {
        version: published.version,
        status: published.status,
        rider_percentage: published.rider_percentage,
        company_commission_percentage: published.company_commission_percentage,
        operational_cost_percentage_of_commission:
          published.operational_cost_percentage_of_commission,
      },
      reason: null,
    });
    return { payment_settings: serializePaymentSettings(published) };
  }
}
