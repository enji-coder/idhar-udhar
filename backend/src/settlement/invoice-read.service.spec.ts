import { INVOICE_INSERT_SQL } from './settlement.repository';
import {
  collectKeys,
  invoiceBilledTotal,
  invoiceFareFromSnapshot,
  toCustomerInvoice,
  InvoiceHeaderRecord,
} from './invoice-document';
import { InvoiceReadService } from './invoice-read.service';
import { SettlementRepository } from './settlement.repository';
import { AuthContext } from '../auth/types/auth-context';
import { ErrorCodes } from '../common/errors/error-codes';

const ORDER = '11111111-1111-4111-8111-111111111111';
const CUSTOMER = '22222222-2222-4222-8222-222222222222';
const OTHER = '33333333-3333-4333-8333-333333333333';

function auth(role: AuthContext['role'], profileId: string): AuthContext {
  return {
    identityId: 'identity',
    sessionId: 'session',
    role,
    profileId,
  };
}

function header(overrides: Partial<InvoiceHeaderRecord> = {}): InvoiceHeaderRecord {
  return {
    invoice_number: 'INV-IU-AMD-0000000001',
    status: 'ISSUED',
    issued_at: new Date('2026-08-14T10:15:00.000Z'),
    trip_fare: '135.00',
    discount: '10.00',
    additional_locked_charges: '5.00',
    rounding: '-0.40',
    billed_total: '129.60',
    customer_paid: '129.60',
    receiver_paid: '0.00',
    payment_status_snapshot: 'PAID',
    order_id: ORDER,
    crn: 'IU-CRN-AMD-0000000001',
    canonical_status: 'DELIVERED',
    pickup_address: 'Pickup lane',
    pickup_contact_name: 'Asha',
    pickup_contact_phone: '9000000001',
    drop_address: 'Drop lane',
    drop_contact_name: 'Ravi',
    drop_contact_phone: '9000000002',
    trip_completed_at: new Date('2026-08-14T11:00:00.000Z'),
    vehicle_category: 'Bike',
    vehicle_registration: 'GJ01AB1234',
    customer_planned_online: '0.00',
    customer_planned_cash: '129.60',
    receiver_planned_online: null,
    receiver_planned_cash: null,
    ...overrides,
  };
}

describe('stored customer invoice', () => {
  it('keeps a new invoice insert idempotent and copies snapshot money', () => {
    expect(INVOICE_INSERT_SQL).toContain('ON CONFLICT (order_id) DO NOTHING');
    expect(INVOICE_INSERT_SQL).not.toContain('UPDATE invoices');
    expect(INVOICE_INSERT_SQL).toContain('gst_on_fare');
    expect(INVOICE_INSERT_SQL).toContain(', 0,');
    const fare = invoiceFareFromSnapshot({
      trip_fare: '135.00',
      discount: '10.00',
      rounding: '-0.40',
      net_payable: '124.60',
    });
    expect(invoiceBilledTotal(fare.netPayable, '5.00')).toBe('129.60');
  });

  it('returns the stored bill without commission or GST fields', () => {
    const document = toCustomerInvoice(header(), [
      { sequence: 0, line_type: 'TRIP_FARE', label: 'Trip Fare', amount: '135.00' },
      { sequence: 1, line_type: 'DISCOUNT', label: 'Discount', amount: '10.00' },
      { sequence: 2, line_type: 'WAITING', label: 'Waiting Charges', amount: '5.00' },
      { sequence: 3, line_type: 'COMMISSION', label: 'Rider share', amount: '100.00' },
    ]);
    expect(document).toMatchObject({
      invoice_number: 'INV-IU-AMD-0000000001',
      crn: 'IU-CRN-AMD-0000000001',
      trip_fare: '135.00',
      discount: '10.00',
      additional_charges: '5.00',
      subtotal: '130.00',
      rounding: '-0.40',
      net_payable: '129.60',
    });
    expect(document.lines.map((line) => line.line_type)).toEqual([
      'TRIP_FARE',
      'DISCOUNT',
      'WAITING',
    ]);
    const keys = collectKeys(document);
    for (const hidden of [
      'gst',
      'gstin',
      'sac',
      'tax',
      'rider_amount',
      'company_amount',
      'rider_percentage',
      'company_commission',
    ]) {
      expect(keys.has(hidden)).toBe(false);
    }
  });

  it('serves the same stored invoice to the customer and the admin', async () => {
    const stored = header();
    const lines = [
      { sequence: 0, line_type: 'TRIP_FARE', label: 'Trip Fare', amount: '135.00' },
    ];
    const repo = {
      findInvoiceAccess: jest.fn(async () => ({
        order_id: ORDER,
        customer_profile_id: CUSTOMER,
        canonical_status: 'DELIVERED',
        crn: stored.crn,
      })),
      findInvoiceHeader: jest.fn(async () => stored),
      findInvoiceLines: jest.fn(async () => lines),
    };
    const service = new InvoiceReadService(repo as unknown as SettlementRepository);
    const customer = await service.getForCustomer(auth('CUSTOMER', CUSTOMER), ORDER);
    const admin = await service.getForAdmin(auth('ADMIN', 'admin-profile'), ORDER);
    expect(admin).toEqual(customer);
    expect(customer.net_payable).toBe('129.60');
    expect(customer.discount).toBe('10.00');
  });

  it('hides invoices for another customer, a cancelled order, and an in-progress order', async () => {
    const repo = {
      findInvoiceAccess: jest.fn(async () => ({
        order_id: ORDER,
        customer_profile_id: CUSTOMER,
        canonical_status: 'DELIVERED',
        crn: 'IU-CRN-AMD-0000000001',
      })),
      findInvoiceHeader: jest.fn(),
      findInvoiceLines: jest.fn(),
    };
    const service = new InvoiceReadService(repo as unknown as SettlementRepository);

    await expect(service.getForCustomer(auth('CUSTOMER', OTHER), ORDER)).rejects.toMatchObject({
      code: ErrorCodes.NOT_FOUND,
      status: 404,
    });

    repo.findInvoiceAccess.mockResolvedValueOnce({
      order_id: ORDER,
      customer_profile_id: CUSTOMER,
      canonical_status: 'CANCELLED',
      crn: 'IU-CRN-AMD-0000000001',
    });
    await expect(service.getForCustomer(auth('CUSTOMER', CUSTOMER), ORDER)).rejects.toMatchObject({
      code: ErrorCodes.INVOICE_ORDER_CANCELLED,
      status: 409,
    });

    repo.findInvoiceAccess.mockResolvedValueOnce({
      order_id: ORDER,
      customer_profile_id: CUSTOMER,
      canonical_status: 'IN_TRANSIT',
      crn: 'IU-CRN-AMD-0000000001',
    });
    await expect(service.getForAdmin(auth('ADMIN', 'admin-profile'), ORDER)).rejects.toMatchObject({
      code: ErrorCodes.INVOICE_NOT_READY,
      status: 409,
    });

    repo.findInvoiceAccess.mockResolvedValueOnce({
      order_id: ORDER,
      customer_profile_id: CUSTOMER,
      canonical_status: 'DELIVERED',
      crn: 'IU-CRN-AMD-0000000001',
    });
    repo.findInvoiceHeader.mockResolvedValueOnce(null);
    await expect(service.getForCustomer(auth('CUSTOMER', CUSTOMER), ORDER)).rejects.toMatchObject({
      code: ErrorCodes.INVOICE_NOT_READY,
      status: 409,
    });
    expect(repo.findInvoiceLines).not.toHaveBeenCalled();
  });

  it('rejects a customer token on the admin read', async () => {
    const service = new InvoiceReadService({} as SettlementRepository);
    await expect(service.getForAdmin(auth('CUSTOMER', CUSTOMER), ORDER)).rejects.toMatchObject({
      code: ErrorCodes.FORBIDDEN,
      status: 403,
    });
  });
});
