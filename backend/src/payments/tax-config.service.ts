import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { PostgresService } from '../database/postgres.service';
import { AuditService } from '../audit/audit.service';
import {
  assertAdminFinance,
  assertTaxConfigWriter,
} from './admin-finance.acl';
import { PublishTaxConfigDto } from './dto/publish-tax-config.dto';
import { parsePercent } from './gst-math';
import { serializeTaxConfig, TaxConfigRepository } from './tax-config.repository';

@Injectable()
export class TaxConfigService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly repo: TaxConfigRepository,
    private readonly identities: IdentityRepository,
    private readonly audit: AuditService,
  ) {}

  async get(auth: AuthContext) {
    await assertAdminFinance(this.identities, auth);
    const [active, versions] = await Promise.all([
      this.repo.findActive(),
      this.repo.listVersions(),
    ]);
    return {
      applies_to: 'COMPANY_COMMISSION',
      note: 'GST here applies to the company commission only. GST on the customer trip fare remains 0.',
      active: active ? serializeTaxConfig(active) : null,
      versions: versions.map((row) => serializeTaxConfig(row)),
    };
  }

  /**
   * Publishes version N+1. The previous version is superseded, never edited, so
   * every report over a past period keeps the rate and basis it was run with.
   */
  async publish(auth: AuthContext, body: PublishTaxConfigDto) {
    const profile = await assertTaxConfigWriter(this.identities, auth);
    const rate = this.parseRate(body.gst_rate);

    if (body.gst_calculation_basis === 'NONE' && rate !== '0.00') {
      throw new ApiError(
        ErrorCodes.TAX_CONFIG_INVALID,
        'NONE basis requires a GST rate of 0',
        422,
      );
    }
    if (body.gst_calculation_basis !== 'NONE' && rate === '0.00') {
      throw new ApiError(
        ErrorCodes.TAX_CONFIG_INVALID,
        'A 0 GST rate must be published with the NONE basis so reports state it explicitly',
        422,
      );
    }

    const now = new Date();
    const effectiveFrom = body.effective_from
      ? new Date(body.effective_from)
      : now;
    if (Number.isNaN(effectiveFrom.getTime())) {
      throw new ApiError(
        ErrorCodes.TAX_CONFIG_INVALID,
        'effective_from is not a valid timestamp',
        422,
      );
    }
    // Backdating would retroactively change the rate resolved for orders that
    // were frozen before this version existed. Historical reports must not move.
    if (effectiveFrom.getTime() < now.getTime() - 60_000) {
      throw new ApiError(
        ErrorCodes.TAX_CONFIG_INVALID,
        'effective_from cannot be backdated; historical financial records keep the configuration that applied at the time',
        422,
      );
    }

    const previous = await this.repo.findActive();
    const published = await this.postgres.transaction((tx) =>
      this.repo.publish(
        {
          adminProfileId: profile.admin_profile_id,
          gstRate: rate,
          gstCalculationBasis: body.gst_calculation_basis,
          effectiveFrom,
          notes: body.notes ?? null,
        },
        tx,
      ),
    );

    await this.audit.record({
      auth,
      action: 'TAX_CONFIG_PUBLISHED',
      entityType: 'TAX_CONFIG_VERSION',
      entityId: published.tax_config_version_id,
      category: 'FINANCIAL',
      oldValue: previous
        ? {
            version: previous.version,
            gst_rate: previous.gst_rate,
            gst_calculation_basis: previous.gst_calculation_basis,
          }
        : null,
      newValue: {
        version: published.version,
        gst_rate: published.gst_rate,
        gst_calculation_basis: published.gst_calculation_basis,
        effective_from: published.effective_from.toISOString(),
      },
      reason: body.notes ?? null,
    });

    return { tax_config: serializeTaxConfig(published) };
  }

  private parseRate(raw: string): string {
    try {
      return parsePercent(raw);
    } catch {
      throw new ApiError(
        ErrorCodes.TAX_CONFIG_INVALID,
        'gst_rate must be between 0 and 100 with up to 2 decimals',
        422,
      );
    }
  }
}
