import { ApiError } from '../common/errors/api-error';
import { FareQuoteRow } from './fare.repository';
import { FareService } from './fare.service';

const CUSTOMER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const TRUCK = '11111111-1111-4111-8111-111111111111';
const TEMPO = '22222222-2222-4222-8222-222222222222';
const VERSION = '33333333-3333-4333-8333-333333333333';

function quote(overrides: Partial<FareQuoteRow> = {}): FareQuoteRow {
  return {
    fare_quote_id: '44444444-4444-4444-8444-444444444444',
    customer_profile_id: CUSTOMER,
    fare_config_version_id: VERSION,
    vehicle_category_id: TRUCK,
    distance_km: '12.000',
    stop_count: 2,
    base_fare: '100.00',
    per_km: '10.00',
    distance_charge: '120.00',
    initial_minimum: '50.00',
    waiting: '0.00',
    surge: '0.00',
    toll: '0.00',
    parking: '0.00',
    initial_waiting_minutes: 0,
    waiting_charge_per_minute: '0.00',
    trip_fare: '220.00',
    discount: '0.00',
    rounding: '0.00',
    net_payable: '220.00',
    tax: '0.00',
    rider_percentage: '85.00',
    company_commission_percentage: '15.00',
    expires_at: new Date('2099-01-01T00:00:00.000Z'),
    created_at: new Date('2026-09-28T00:00:00.000Z'),
    ...overrides,
  };
}

function serviceWith(insert: jest.Mock) {
  return new FareService(
    { insertQuoteFromActiveConfig: insert } as never,
    { getOrThrow: () => ({ quoteTtlSeconds: 900 }) } as never,
  );
}

describe('FareService vehicle quotes', () => {
  it('prices 12 km from the selected vehicle category, not the previous one', async () => {
    const insert = jest
      .fn()
      .mockResolvedValueOnce(quote({ vehicle_category_id: TRUCK, trip_fare: '819.00' }))
      .mockResolvedValueOnce(quote({ vehicle_category_id: TEMPO, trip_fare: '420.00' }));
    const service = serviceWith(insert);
    const db = {};
    const truck = await service.quoteFromActiveConfig(
      {
        customerProfileId: CUSTOMER,
        vehicleCategoryId: TRUCK,
        distanceKm: '12',
        stopCount: 2,
      },
      db as never,
    );
    const tempo = await service.quoteFromActiveConfig(
      {
        customerProfileId: CUSTOMER,
        vehicleCategoryId: TEMPO,
        distanceKm: '12',
        stopCount: 2,
      },
      db as never,
    );

    expect(insert.mock.calls[0][0]).toMatchObject({
      vehicleCategoryId: TRUCK,
      distanceKm: '12.000',
    });
    expect(insert.mock.calls[1][0]).toMatchObject({
      vehicleCategoryId: TEMPO,
      distanceKm: '12.000',
    });
    expect(truck.trip_fare).toBe('819.00');
    expect(tempo.trip_fare).toBe('420.00');
  });

  it('rejects a quote whose distance belongs to a different route', () => {
    const service = serviceWith(jest.fn());
    expect(() =>
      service.assertQuoteUsable({
        quote: quote({ distance_km: '1.000' }),
        customerProfileId: CUSTOMER,
        vehicleCategoryId: TRUCK,
        stopCount: 2,
        distanceKm: '12.000',
      }),
    ).toThrow(ApiError);
  });

  it('rejects a quote that adds GST', () => {
    const service = serviceWith(jest.fn());
    expect(() =>
      service.assertQuoteUsable({
        quote: quote({ tax: '5.00' }),
        customerProfileId: CUSTOMER,
        vehicleCategoryId: TRUCK,
        stopCount: 2,
        distanceKm: '12.000',
      }),
    ).toThrow('Fare quote tax must be 0');
  });

  it('accepts the quote when the routed distance and zero tax match', () => {
    const service = serviceWith(jest.fn());
    expect(() =>
      service.assertQuoteUsable({
        quote: quote(),
        customerProfileId: CUSTOMER,
        vehicleCategoryId: TRUCK,
        stopCount: 2,
        distanceKm: '12',
      }),
    ).not.toThrow();
  });
});
