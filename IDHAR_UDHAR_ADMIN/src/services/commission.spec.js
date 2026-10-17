import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { paymentSettingsFromApi, paymentSettingsPayload } from './commission.js';

describe('payment settings mapping', () => {
  it('loads the persisted active split without replacing it with the 85/15 default', () => {
    const settings = paymentSettingsFromApi({
      rider_percentage: '80.00',
      company_commission_percentage: '20.00',
      operational_cost_percentage_of_commission: '40.00',
      version: 2,
      status: 'ACTIVE',
    });
    assert.deepEqual(settings, {
      riderSharePercent: 80,
      companyCommissionPercent: 20,
      operationalCostPercent: 40,
    });
    assert.equal(paymentSettingsFromApi(null), null);
  });

  it('loads and saves an active 85/15/50 record as percentages', () => {
    const loaded = paymentSettingsFromApi({
      rider_percentage: 85,
      company_commission_percentage: 15,
      operational_cost_percentage_of_commission: 50,
      version: 1,
      status: 'ACTIVE',
    });
    assert.deepEqual(loaded, {
      riderSharePercent: 85,
      companyCommissionPercent: 15,
      operationalCostPercent: 50,
    });
    assert.deepEqual(paymentSettingsPayload(loaded), {
      rider_percentage: '85.00',
      company_commission_percentage: '15.00',
      operational_cost_percentage_of_commission: '50.00',
    });
  });

  it('sends the admin percentages to the existing payment-settings endpoint', () => {
    assert.deepEqual(paymentSettingsPayload({
      riderSharePercent: 80,
      companyCommissionPercent: 20,
      operationalCostPercent: 40,
    }), {
      rider_percentage: '80.00',
      company_commission_percentage: '20.00',
      operational_cost_percentage_of_commission: '40.00',
    });
  });
});
