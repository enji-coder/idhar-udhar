import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { AppLogger } from '../common/logger/app-logger';
import { formatInr } from '../fare/money';
import { AuditService } from '../audit/audit.service';
import { assertAdminFinance } from '../payments/admin-finance.acl';
import { TaxConfigRepository } from '../payments/tax-config.repository';
import { GstReportQueryDto, GroupBy } from './dto/gst-report-query.dto';
import { resolveRange, ResolvedRange } from './date-range';
import {
  EXPORT_MAX_ROWS,
  GstDetailRow,
  GstReportFilters,
  GstReportRepository,
} from './gst-report.repository';
import { buildGstWorkbook } from './gst-workbook';

const DEFAULT_LIMIT = 50;

/**
 * The report reads the immutable ORIGINAL finance snapshot as the single
 * authoritative revenue record, then applies the GST configuration frozen for
 * that snapshot.
 *
 * Out of scope by design, so the 85/15 arithmetic stays coherent:
 *   - resend_snapshots.company_amount (Case B 2/km, office handover 8/km)
 *   - order_cancellation_snapshots.company_amount
 *   - order_adjustments
 * These are company money but do not follow the 85/15 commission split. The
 * response labels the scope so this is never mistaken for total company revenue.
 */
const REPORT_SCOPE_NOTE =
  'Trip commission GST. Based on the ORIGINAL order finance snapshot (85/15 freeze). Excludes resend company amounts, cancellation company shares and order adjustments, which do not follow the 85/15 split. GST on the customer trip fare is 0.';

@Injectable()
export class GstReportService {
  constructor(
    private readonly repo: GstReportRepository,
    private readonly taxConfig: TaxConfigRepository,
    private readonly identities: IdentityRepository,
    private readonly audit: AuditService,
    private readonly logger: AppLogger,
  ) {}

  async gstReport(auth: AuthContext, query: GstReportQueryDto) {
    const profile = await assertAdminFinance(this.identities, auth);
    const range = resolveRange(query);
    const filters = toFilters(query);
    const groupBy: GroupBy = query.group_by ?? 'day';
    const limit = query.limit ?? DEFAULT_LIMIT;
    const offset = query.offset ?? 0;

    const [summary, groups, rates, detail, activeConfig] = await Promise.all([
      this.repo.summary(range, filters),
      this.repo.grouped(range, filters, groupBy),
      this.repo.rateBreakdown(range, filters),
      this.repo.detail(range, filters, { limit, offset }),
      this.taxConfig.findActive(),
    ]);

    await this.recordAudit(auth, 'GST_REPORT_VIEWED', range, filters, {
      order_count: Number(summary.order_count),
      group_by: groupBy,
      limit,
      offset,
    });

    return {
      scope: REPORT_SCOPE_NOTE,
      period: {
        preset: range.preset,
        from_date: range.from_date,
        to_date: range.to_date,
        time_zone: range.time_zone,
        date_basis: 'FINANCE_FREEZE',
      },
      active_tax_config: activeConfig
        ? {
            tax_config_version_id: activeConfig.tax_config_version_id,
            version: activeConfig.version,
            gst_rate: activeConfig.gst_rate,
            gst_calculation_basis: activeConfig.gst_calculation_basis,
          }
        : null,
      applied_filters: describeFilters(query),
      summary: serializeSummary(summary),
      gst_rates_applied: rates.map((row) => ({
        gst_rate: row.gst_rate,
        gst_basis: row.gst_basis,
        order_count: Number(row.order_count),
        company_commission: formatInr(row.company_commission),
        gst_amount: formatInr(row.gst_amount),
      })),
      group_by: groupBy,
      groups: groups.map((row) => ({
        period: row.period,
        order_count: Number(row.order_count),
        trip_fare: formatInr(row.trip_fare),
        rider_share: formatInr(row.rider_share),
        company_commission: formatInr(row.company_commission),
        taxable_company_amount: formatInr(row.taxable_company_amount),
        gst_amount: formatInr(row.gst_amount),
        operational_cost: formatInr(row.operational_cost),
        company_profit: formatInr(row.company_profit),
      })),
      page: {
        limit,
        offset,
        returned: detail.length,
        total: Number(summary.order_count),
      },
      records: detail.map((row) => serializeDetail(row)),
      generated_at: new Date().toISOString(),
      generated_by: profile.admin_profile_id,
    };
  }

  async export(auth: AuthContext, query: GstReportQueryDto) {
    const profile = await assertAdminFinance(this.identities, auth);
    const range = resolveRange(query);
    const filters = toFilters(query);
    const groupBy: GroupBy = query.group_by ?? 'day';

    const [summary, groups, detail] = await Promise.all([
      this.repo.summary(range, filters),
      this.repo.grouped(range, filters, groupBy),
      // The export ignores on-screen pagination and applies exactly the same
      // filters, so the file matches the filtered result set rather than a page.
      this.repo.detail(range, filters, { limit: EXPORT_MAX_ROWS, offset: 0 }),
    ]);

    const truncated = detail.length >= EXPORT_MAX_ROWS;
    if (truncated) {
      this.logger.warn('gst_report_export_truncated', {
        rows: detail.length,
        max_rows: EXPORT_MAX_ROWS,
      });
    }

    const generatedAt = new Date();
    const buffer = await buildGstWorkbook({
      range,
      generatedAt,
      generatedBy: profile.admin_profile_id,
      appliedFilters: describeFilters(query),
      summary,
      groups,
      groupLabel: groupBy,
      detail,
      truncated,
      exportMaxRows: EXPORT_MAX_ROWS,
    });

    await this.recordAudit(auth, 'GST_REPORT_EXPORTED', range, filters, {
      order_count: Number(summary.order_count),
      exported_rows: detail.length,
      truncated,
      format: 'xlsx',
    });

    return {
      buffer,
      filename: `gst-report_${range.from_date}_to_${range.to_date}.xlsx`,
    };
  }

  private async recordAudit(
    auth: AuthContext,
    action: string,
    range: ResolvedRange,
    filters: GstReportFilters,
    extra: Record<string, unknown>,
  ): Promise<void> {
    const runId = await this.audit.newEntityId();
    await this.audit.record({
      auth,
      action,
      entityType: 'GST_REPORT_RUN',
      entityId: runId,
      category: 'FINANCIAL',
      newValue: {
        report_type: 'GST_TRIP_COMMISSION',
        from_date: range.from_date,
        to_date: range.to_date,
        preset: range.preset,
        time_zone: range.time_zone,
        date_basis: 'FINANCE_FREEZE',
        filters,
        ...extra,
      },
    });
  }
}

function toFilters(query: GstReportQueryDto): GstReportFilters {
  return {
    order_id: query.order_id,
    display_id: query.display_id,
    customer_profile_id: query.customer_profile_id,
    rider_profile_id: query.rider_profile_id,
    city_id: query.city_id,
    vehicle_category_id: query.vehicle_category_id,
    order_status: query.order_status,
    payment_status: query.payment_status,
    payment_method: query.payment_method,
  };
}

/** Human-readable filter echo, used in the response and the Excel summary. */
function describeFilters(query: GstReportQueryDto): Record<string, string> {
  const filters = toFilters(query);
  const described: Record<string, string> = {};
  for (const [key, value] of Object.entries(filters)) {
    if (value != null && value !== '') {
      described[key] = String(value);
    }
  }
  return described;
}

function serializeSummary(row: {
  order_count: string;
  unconfigured_order_count: string;
  total_trip_fare: string;
  total_rider_share: string;
  total_company_commission: string;
  total_taxable_company_amount: string;
  total_gst: string;
  total_operational_cost: string;
  total_company_profit: string;
}) {
  return {
    order_count: Number(row.order_count),
    unconfigured_order_count: Number(row.unconfigured_order_count),
    total_trip_fare: formatInr(row.total_trip_fare),
    total_rider_share: formatInr(row.total_rider_share),
    total_company_commission: formatInr(row.total_company_commission),
    total_taxable_company_amount: formatInr(row.total_taxable_company_amount),
    total_gst: formatInr(row.total_gst),
    total_operational_cost: formatInr(row.total_operational_cost),
    total_company_profit: formatInr(row.total_company_profit),
  };
}

function serializeDetail(row: GstDetailRow) {
  return {
    date: row.report_date,
    frozen_at: row.frozen_at.toISOString(),
    order_id: row.order_id,
    display_id: row.display_id,
    finance_snapshot_id: row.finance_snapshot_id,
    customer_profile_id: row.customer_profile_id,
    customer_name: row.customer_name,
    rider_profile_id: row.rider_profile_id,
    rider_phone: row.rider_phone,
    city_code: row.city_code,
    city_name: row.city_name,
    vehicle_category_name: row.vehicle_category_name,
    order_status: row.order_status,
    payment_status: row.payment_status,
    trip_fare: formatInr(row.trip_fare),
    rider_percentage: formatInr(row.rider_percentage),
    rider_share: formatInr(row.rider_amount),
    company_commission_percentage: formatInr(row.company_commission_percentage),
    company_commission: formatInr(row.company_commission_amount),
    operational_cost_percentage_of_commission: formatInr(
      row.operational_cost_percentage_of_commission,
    ),
    operational_cost: formatInr(row.operational_cost_amount),
    gst_rate: row.gst_rate,
    gst_basis: row.gst_basis ?? 'UNCONFIGURED',
    gst_amount: row.gst_amount == null ? null : formatInr(row.gst_amount),
    taxable_company_amount:
      row.taxable_company_amount == null
        ? null
        : formatInr(row.taxable_company_amount),
    company_profit:
      row.company_profit_amount == null
        ? null
        : formatInr(row.company_profit_amount),
    tax_frozen: row.tax_frozen,
    tax_config_version_id: row.tax_config_version_id,
  };
}
