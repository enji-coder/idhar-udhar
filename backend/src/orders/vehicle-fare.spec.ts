import { readFileSync } from 'fs';
import { join } from 'path';
import {
  faresByVehicle,
  isCustomerBookableVehicle,
  serializeCustomerVehicleFare,
  VehicleFarePreviewRow,
} from './vehicle-fare';

const TRUCK = '11111111-1111-4111-8111-111111111111';
const TEMPO = '22222222-2222-4222-8222-222222222222';
const VERSION = '33333333-3333-4333-8333-333333333333';

function row(
  overrides: Partial<VehicleFarePreviewRow> &
    Pick<VehicleFarePreviewRow, 'vehicle_category_id' | 'vehicle' | 'trip_fare'>,
): VehicleFarePreviewRow {
  return {
    name: overrides.vehicle === 'tempo' ? 'Tempo' : 'Truck',
    vehicle_type: 'truck',
    active: true,
    weight_capacity: '1000 kg',
    size: null,
    fare_config_version_id: VERSION,
    base_fare: '100.00',
    distance_charge: '50.00',
    waiting: '0.00',
    surge: '0.00',
    toll: '0.00',
    parking: '0.00',
    discount: '0.00',
    rounding: '0.00',
    net_payable: overrides.trip_fare,
    tax: '0.00',
    ...overrides,
  };
}

describe('customer vehicle fares', () => {
  it('keeps each vehicle fare for the same 12 km route', () => {
    const fares = faresByVehicle([
      row({ vehicle_category_id: TRUCK, vehicle: 'truck', trip_fare: '819.00', net_payable: '819.00' }),
      row({
        vehicle_category_id: TEMPO,
        vehicle: 'tempo',
        name: 'Tempo',
        trip_fare: '420.00',
        net_payable: '420.00',
      }),
    ]);

    expect(fares.get(TRUCK)).toBe('819.00');
    expect(fares.get(TEMPO)).toBe('420.00');
    expect(fares.get(TEMPO)).not.toBe(fares.get(TRUCK));
  });

  it('keeps an active category with no slug and drops a mixed pair', () => {
    const openId = '01a18c7f-0483-7740-8e37-5bdd836f2159';
    expect(
      isCustomerBookableVehicle({
        active: true,
        vehicle_type: null,
        vehicle: null,
      }),
    ).toBe(true);
    expect(
      isCustomerBookableVehicle({
        active: true,
        vehicle_type: 'two_wheeler',
        vehicle: 'bike',
      }),
    ).toBe(true);
    expect(
      isCustomerBookableVehicle({
        active: false,
        vehicle_type: null,
        vehicle: null,
      }),
    ).toBe(false);
    expect(
      isCustomerBookableVehicle({
        active: true,
        vehicle_type: 'truck',
        vehicle: null,
      }),
    ).toBe(false);
    expect(
      isCustomerBookableVehicle({
        active: true,
        vehicle_type: 'two_wheeler',
        vehicle: 'truck',
      }),
    ).toBe(false);
    const fares = faresByVehicle([
      row({
        vehicle_category_id: openId,
        vehicle: null,
        vehicle_type: null,
        name: '3W Tempo',
        trip_fare: '420.00',
        net_payable: '420.00',
      }),
    ]);
    expect(fares.get(openId)).toBe('420.00');
  });

  it('drops an inactive vehicle', () => {
    const fares = faresByVehicle([
      row({
        vehicle_category_id: TRUCK,
        vehicle: 'truck',
        trip_fare: '819.00',
        active: false,
      }),
    ]);
    expect(fares.has(TRUCK)).toBe(false);
  });

  it('exposes the trip breakdown without GST or commission', () => {
    const body = serializeCustomerVehicleFare(
      row({ vehicle_category_id: TRUCK, vehicle: 'truck', trip_fare: '819.00' }),
    );
    expect(body.fare.tax).toBe('0.00');
    expect(body.fare.trip_fare).toBe('819.00');
    expect(body.weight_capacity_kg).toBe('1000.000');
    const encoded = JSON.stringify(body);
    expect(encoded).not.toContain('rider_percentage');
    expect(encoded).not.toContain('company_commission');
    expect(encoded).not.toContain('gst');
  });

  it('refuses a customer fare that includes tax', () => {
    expect(() =>
      serializeCustomerVehicleFare(
        row({
          vehicle_category_id: TRUCK,
          vehicle: 'truck',
          trip_fare: '819.00',
          tax: '5.00',
        }),
      ),
    ).toThrow('Customer vehicle fare tax must be 0');
  });

  it('prices active categories that have rates even when both slugs are blank', () => {
    const source = readFileSync(
      join(__dirname, '../fare/fare.repository.ts'),
      'utf8',
    );
    const start = source.indexOf('async previewActiveVehicleFares');
    const end = source.indexOf('async tripFareForVersion');
    const query = source.slice(start, end);
    expect(start).toBeGreaterThan(-1);
    expect(query).toContain('WHERE c.active = TRUE');
    expect(query).not.toContain('vehicle_type IS NOT NULL');
    expect(query).not.toContain('vehicle IS NOT NULL');
  });
});
