import {
  faresByVehicle,
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
});
