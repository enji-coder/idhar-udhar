import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mapAdminSession, mapCustomer, mapEarning, mapNotice, mapOrder, mapPayment, mapRider, mapVehicleCategory, mapZone, UI_TO_CANONICAL } from './mappers.js';

describe('admin mappers', () => {
  it('maps admin profile role without inventing finance splits', () => {
    const session = mapAdminSession({
      admin_profile_id: 'a1',
      email: 'ops@example.test',
      role: 'OPERATIONS',
      finance_access: false,
      payout_approve: false,
      modules: ['orders'],
      active: true,
    });
    assert.equal(session.role, 'Operations');
    assert.equal(session.financeAccess, false);
    assert.deepEqual(session.modules, ['orders']);
  });

  it('maps canonical order status and uses frozen snapshot amounts', () => {
    const order = mapOrder({
      order_id: '11111111-1111-4111-8111-111111111111',
      display_id: '1001',
      customer_profile_id: 'c1',
      customer_display_name: 'Asha',
      customer_phone: '9876543210',
      rider_profile_id: 'r1',
      rider_phone: '9123456789',
      pickup_address: 'Pickup',
      drop_address: 'Drop',
      vehicle_category_name: 'Bike',
      canonical_status: 'IN_TRANSIT',
      trip_fare: '100.00',
      net_payable: '100.00',
      created_at: '2026-08-25T10:00:00.000Z',
      updated_at: '2026-08-25T10:05:00.000Z',
      finance_snapshot: {
        trip_fare: '100.00',
        rider_amount: '85.00',
        company_commission_amount: '15.00',
        operational_cost_amount: '7.50',
        profit_amount: '7.50',
        rider_percentage: '85.00',
        company_commission_percentage: '15.00',
        operational_cost_percentage_of_commission: '50.00',
      },
    });
    assert.equal(order.status, 'In Transit');
    assert.equal(order.backendOrderId, '11111111-1111-4111-8111-111111111111');
    assert.equal(order.financeSnapshot.riderAmount, 85);
    assert.equal(order.financeSnapshot.companyCommission, 15);
    assert.equal(UI_TO_CANONICAL['In Transit'], 'IN_TRANSIT');
  });

  it('does not invent a rider display name', () => {
    const rider = mapRider({
      rider_profile_id: 'r1',
      phone_normalized: '9876543210',
      online_status: 'ONLINE',
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      cod_operational_status: 'CLEAR',
    });
    assert.equal(rider.name, 'Rider 3210');
    assert.equal(rider.source, 'api');
  });

  it('ignores Array.map index when mapping customers', () => {
    const customer = mapCustomer({
      customer_profile_id: 'c1',
      display_name: 'Asha',
      phone_normalized: '9876543210',
      status: 'ACTIVE',
    }, 0);
    assert.equal(customer.id, 'c1');
    assert.equal(customer.orders, 0);
  });

  it('maps stored payment and earning amounts without recalculating', () => {
    const payment = mapPayment({
      payment_transaction_id: 'p1',
      display_id: '1001',
      order_id: 'o1',
      payer_type: 'CUSTOMER',
      method: 'CASH',
      amount: '40.00',
      transaction_status: 'PAID',
      created_at: '2026-08-25T10:00:00.000Z',
    });
    assert.equal(payment.amount, 40);
    assert.equal(payment.status, 'Success');
    const earning = mapEarning({
      display_id: '1001',
      order_id: 'o1',
      rider_profile_id: 'r1',
      trip_fare: '100.00',
      rider_amount: '85.00',
      company_commission_amount: '15.00',
      operational_cost_amount: '7.50',
      profit_amount: '7.50',
      frozen_at: '2026-08-25T10:00:00.000Z',
    });
    assert.equal(earning.riderEarning, 85);
    assert.equal(earning.netCompanyEarnings, 7.5);
  });

  it('maps inbox notices from backend fields', () => {
    const notice = mapNotice({
      notification_id: 'n1',
      title: 'Assigned',
      body: 'A rider was assigned.',
      created_at: '2026-08-25T10:00:00.000Z',
      read_at: null,
      type: 'ORDER',
    });
    assert.equal(notice.unread, true);
    assert.equal(notice.title, 'Assigned');
  });

  it('maps vehicle categories from postgres rows without inventing dummy names', () => {
    const row = mapVehicleCategory({
      vehicle_category_id: '11111111-1111-4111-8111-111111111111',
      name: 'Bike',
      active: true,
      weight_capacity: '20',
      size: '36cm',
      created_at: '2026-08-27T00:00:00.000Z',
      updated_at: '2026-08-27T00:00:00.000Z',
      fare_config_version_id: null,
      rates: { base_fare: '79.00', per_km: '0.00', initial_minimum: '79.00', waiting: '0.00', surge: '0.00', toll: '0.00', parking: '0.00' },
      usage: { vehicles: 0, orders: 0, fare_rates: 0 },
    });
    assert.equal(row.id, '11111111-1111-4111-8111-111111111111');
    assert.equal(row.name, 'Bike');
    assert.equal(row.status, 'Active');
    assert.equal(row.baseFare, 79);
    assert.equal(row.source, 'api');
  });

  it('maps zones from postgres rows', () => {
    const zone = mapZone({
      zone_id: '22222222-2222-4222-8222-222222222222',
      name: 'Navrangpura',
      city_name: 'Ahmedabad',
      city_code: 'AMD',
      active: true,
      rider_count: 0,
    });
    assert.equal(zone.name, 'Navrangpura');
    assert.equal(zone.area, 'Ahmedabad');
    assert.equal(zone.status, 'Active');
  });
});
