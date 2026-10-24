import { Workbook } from 'exceljs';
import { GstDetailRow, GstSummaryRow } from './gst-report.repository';
import { buildGstWorkbook } from './gst-workbook';
import { ResolvedRange } from './date-range';

const range: ResolvedRange = {
  preset: 'custom',
  from_date: '2026-10-01',
  to_date: '2026-10-24',
  from_instant: '2026-09-30T18:30:00.000Z',
  to_instant: '2026-10-24T18:30:00.000Z',
  time_zone: 'Asia/Kolkata',
};

const summary: GstSummaryRow = {
  order_count: '1',
  unconfigured_order_count: '0',
  total_trip_fare: '100.00',
  total_rider_share: '80.00',
  total_company_commission: '20.00',
  total_taxable_company_amount: '20.00',
  total_gst: '0.00',
  total_operational_cost: '0.00',
  total_company_profit: '20.00',
};

function detail(customerName: string): GstDetailRow {
  return {
    report_date: '2026-10-24',
    frozen_at: new Date('2026-10-24T08:00:00.000Z'),
    order_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    display_id: 'IU-AMD-0000000001',
    crn: 'IU-CRN-AMD-0000000001',
    finance_snapshot_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    customer_profile_id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    customer_name: customerName,
    rider_profile_id: null,
    rider_phone: null,
    city_code: 'AMD',
    city_name: 'Ahmedabad',
    vehicle_category_name: 'Bike',
    order_status: 'DELIVERED',
    payment_status: 'PAID',
    trip_fare: '100.00',
    rider_percentage: '80.00',
    rider_amount: '80.00',
    company_commission_percentage: '20.00',
    company_commission_amount: '20.00',
    operational_cost_percentage_of_commission: '0.00',
    operational_cost_amount: '0.00',
    gst_rate: '0.00',
    gst_basis: null,
    gst_amount: '0.00',
    taxable_company_amount: '20.00',
    company_profit_amount: '20.00',
    tax_frozen: true,
    tax_config_version_id: null,
  };
}

describe('GST workbook formula guard', () => {
  it('writes filter and customer text so a spreadsheet does not treat it as a formula', async () => {
    const buffer = await buildGstWorkbook({
      range,
      generatedAt: new Date('2026-10-24T08:00:00.000Z'),
      generatedBy: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      appliedFilters: { display_id: '=1+1' },
      summary,
      groups: [],
      groupLabel: 'day',
      detail: [detail('=CMD()')],
      truncated: false,
      exportMaxRows: 50000,
    });
    const workbook = new Workbook();
    await workbook.xlsx.load(buffer as never);
    const values: string[] = [];
    workbook.eachSheet((sheet) => {
      sheet.eachRow((row) => {
        row.eachCell((cell) => {
          if (typeof cell.value === 'string') {
            values.push(cell.value);
          }
        });
      });
    });
    expect(values).toContain("'=1+1");
    expect(values).toContain("'=CMD()");
    expect(values.some((value) => value.startsWith('='))).toBe(false);
  });
});
