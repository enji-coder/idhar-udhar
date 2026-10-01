import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AuthContext } from '../auth/types/auth-context';
import { FareQuoteRow, FareSnapshotRow } from '../fare/fare.repository';
import { FareService } from '../fare/fare.service';
import { ConfirmOrderDto } from './dto/confirm-order.dto';
import { PreviewVehicleFaresDto } from './dto/preview-vehicle-fares.dto';
import { OrderStateMachine } from './order-state-machine';
import { OrderRow } from './orders.repository';
import { canonicalVehiclePairs } from '../catalog/vehicle-catalog';
import { OrdersService } from './orders.service';
import { VehicleFarePreviewRow } from './vehicle-fare';

const CITY = '99999999-9999-4999-8999-999999999999';
const CUSTOMER = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const TRUCK = '11111111-1111-4111-8111-111111111111';
const TEMPO = '22222222-2222-4222-8222-222222222222';
const ORDER = '55555555-5555-4555-8555-555555555555';
const QUOTE = '44444444-4444-4444-8444-444444444444';
const VERSION = '33333333-3333-4333-8333-333333333333';

const auth: AuthContext = {
  identityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  role: 'CUSTOMER',
  profileId: CUSTOMER,
};

function category(overrides: Record<string, unknown> = {}) {
  return {
    vehicle_category_id: TRUCK,
    code: 'TRUCK',
    name: 'Truck',
    active: true,
    weight_capacity: '1000 kg',
    size: 'large',
    vehicle_type: 'truck',
    vehicle: 'truck',
    ...overrides,
  };
}

function orderRow(overrides: Partial<OrderRow> = {}): OrderRow {
  return {
    order_id: ORDER,
    display_id: 'IU-AMD-0000000001',
    customer_profile_id: CUSTOMER,
    rider_profile_id: null,
    city_id: CITY,
    city_code: 'AMD',
    vehicle_category_id: TRUCK,
    vehicle_category_name_snapshot: 'Truck',
    vehicle_id: null,
    canonical_status: 'CREATED',
    package_weight_kg: '10.000',
    parent_order_id: null,
    scheduled_at: null,
    created_at: new Date('2026-09-28T00:00:00.000Z'),
    updated_at: new Date('2026-09-28T00:00:00.000Z'),
    ...overrides,
  };
}

function quote(overrides: Partial<FareQuoteRow> = {}): FareQuoteRow {
  return {
    fare_quote_id: QUOTE,
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
    initial_waiting_minutes: 0,
    waiting_charge_per_minute: '0.00',
    surge: '0.00',
    toll: '0.00',
    parking: '0.00',
    trip_fare: '819.00',
    discount: '0.00',
    rounding: '0.00',
    net_payable: '819.00',
    tax: '0.00',
    rider_percentage: '85.00',
    company_commission_percentage: '15.00',
    expires_at: new Date('2099-01-01T00:00:00.000Z'),
    created_at: new Date('2026-09-28T00:00:00.000Z'),
    ...overrides,
  };
}

function snapshot(tripFare = '819.00'): FareSnapshotRow {
  return {
    fare_snapshot_id: '66666666-6666-4666-8666-666666666666',
    order_id: ORDER,
    fare_config_version_id: VERSION,
    vehicle_category_id: TRUCK,
    vehicle_category_name: 'Truck',
    distance_km: '12.000',
    stop_count: 2,
    base_fare: '100.00',
    per_km: '10.00',
    distance_charge: '120.00',
    initial_minimum: '50.00',
    waiting: '0.00',
    initial_waiting_minutes: 0,
    waiting_charge_per_minute: '0.00',
    surge: '0.00',
    toll: '0.00',
    parking: '0.00',
    trip_fare: tripFare,
    discount: '0.00',
    rounding: '0.00',
    net_payable: tripFare,
    tax: '0.00',
    rider_percentage: '85.00',
    company_commission_percentage: '15.00',
    rider_amount: '696.15',
    quoted_at: new Date('2026-09-28T00:00:00.000Z'),
    confirmed_at: new Date('2026-09-28T00:05:00.000Z'),
  };
}

function previewRow(
  overrides: Partial<VehicleFarePreviewRow> &
    Pick<VehicleFarePreviewRow, 'vehicle_category_id' | 'vehicle' | 'trip_fare'>,
): VehicleFarePreviewRow {
  return {
    name: 'Truck',
    vehicle_type: 'truck',
    active: true,
    weight_capacity: '1000 kg',
    size: null,
    fare_config_version_id: VERSION,
    base_fare: '100.00',
    distance_charge: '120.00',
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

function stops() {
  return [
    {
      sequence: 0,
      stop_type: 'PICKUP' as const,
      address_text: 'Pickup',
      latitude: 23,
      longitude: 72,
    },
    {
      sequence: 1,
      stop_type: 'DROP' as const,
      address_text: 'Drop',
      latitude: 23.1,
      longitude: 72.1,
    },
  ];
}

function build() {
  const orders = {
    allocateDisplayId: jest.fn(async () => 'IU-AMD-0000000001'),
    insertOrder: jest.fn(
      async (input: { packageWeightKg: number | null; vehicleCategoryId: string }) =>
        orderRow({
          vehicle_category_id: input.vehicleCategoryId,
          package_weight_kg:
            input.packageWeightKg == null ? null : input.packageWeightKg.toFixed(3),
        }),
    ),
    insertStops: jest.fn(async () => []),
    insertStatusEvent: jest.fn(async () => undefined),
    lockById: jest.fn(async () => orderRow()),
    listStops: jest.fn(async () => [
      { sequence: 0, latitude: '23.000000', longitude: '72.000000' },
      { sequence: 1, latitude: '23.100000', longitude: '72.100000' },
    ]),
    compareAndSetStatus: jest.fn(async () =>
      orderRow({ canonical_status: 'SEARCHING' }),
    ),
  };
  const catalog = {
    findActiveCity: jest.fn(async () => ({
      city_id: CITY,
      name: 'Ahmedabad',
      city_code: 'AMD',
      active: true,
    })),
    findActiveVehicleCategory: jest.fn(async () => category()),
    findZone: jest.fn(),
  };
  const fares = {
    previewActiveVehicleFares: jest.fn(),
    findSnapshotByOrder: jest.fn(async () => null),
    findQuote: jest.fn(async () => quote()),
    tripFareForVersion: jest.fn(async () => '819.00'),
    insertSnapshotFromQuote: jest.fn(async () => snapshot()),
    insertQuoteFromActiveConfig: jest.fn(),
  };
  const routing = {
    routeStops: jest.fn(async () => ({ distanceMeters: 12000 })),
    distanceKm: jest.fn(() => '12.000'),
    toResponse: jest.fn(() => ({ distance_meters: 12000 })),
  };
  const service = new OrdersService(
    { transaction: async (work: (db: object) => Promise<unknown>) => work({}) } as never,
    orders as never,
    catalog as never,
    fares as never,
    new FareService(fares as never, { getOrThrow: () => ({ quoteTtlSeconds: 900 }) } as never),
    routing as never,
    { find: jest.fn(async () => null), insert: jest.fn(async () => undefined) } as never,
    new OrderStateMachine(),
    { getOrThrow: jest.fn() } as never,
    {} as never,
    { onStatusChange: jest.fn(async () => undefined) } as never,
    {
      assertNoOutstanding: jest.fn(async () => undefined),
      onPickedUp: jest.fn(async () => undefined),
      onCancelled: jest.fn(async () => undefined),
      settleDelivered: jest.fn(async () => undefined),
    } as never,
  );
  return { service, orders, catalog, fares, routing };
}

describe('vehicle fare booking', () => {
  it('returns each active vehicle fare for the routed distance', async () => {
    const { service, fares } = build();
    fares.previewActiveVehicleFares.mockResolvedValue([
      previewRow({ vehicle_category_id: TRUCK, vehicle: 'truck', trip_fare: '819.00' }),
      previewRow({
        vehicle_category_id: TEMPO,
        vehicle: 'tempo',
        name: 'Tempo',
        trip_fare: '420.00',
        net_payable: '420.00',
        weight_capacity: '500 kg',
      }),
      previewRow({
        vehicle_category_id: '77777777-7777-4777-8777-777777777777',
        vehicle: 'bike',
        vehicle_type: 'two_wheeler',
        name: 'Bike',
        trip_fare: '79.00',
        active: false,
      }),
    ]);

    const body = await service.previewVehicleFares(auth, {
      city_id: CITY,
      stops: stops(),
    });

    expect(fares.previewActiveVehicleFares).toHaveBeenCalledWith('12.000');
    expect(body.distance_km).toBe('12.000');
    expect(body.vehicles.map((row) => row.fare.trip_fare)).toEqual(['819.00', '420.00']);
    expect(JSON.stringify(body)).not.toContain('rider_percentage');
    expect(body.vehicles[0].fare.tax).toBe('0.00');
  });

  it('rejects an inactive vehicle before an order is stored', async () => {
    const { service, catalog, orders } = build();
    catalog.findActiveVehicleCategory.mockResolvedValue(category({ active: false }));
    await expect(
      service.create(
        auth,
        { city_id: CITY, vehicle_category_id: TRUCK, package_weight_kg: 10, stops: stops() },
        'idem-1',
      ),
    ).rejects.toMatchObject({
      code: 'VEHICLE_CATEGORY_INVALID',
      message: 'Vehicle category was not found or is inactive',
      status: 400,
    });
    expect(orders.insertOrder).not.toHaveBeenCalled();
  });

  it.each(canonicalVehiclePairs())(
    'accepts canonical $vehicleType / $vehicle',
    async ({ vehicleType, vehicle }) => {
      const { service, catalog, orders } = build();
      const vehicleCategoryId = {
        bike: '11111111-1111-4111-8111-111111111101',
        scooty: '11111111-1111-4111-8111-111111111102',
        loader_riksha: '11111111-1111-4111-8111-111111111103',
        mini_truck: '11111111-1111-4111-8111-111111111104',
        tempo: '11111111-1111-4111-8111-111111111105',
        large_tempo: '11111111-1111-4111-8111-111111111106',
        truck: '11111111-1111-4111-8111-111111111107',
      }[vehicle];
      catalog.findActiveVehicleCategory.mockResolvedValue(
        category({
          vehicle_category_id: vehicleCategoryId,
          name: vehicle,
          vehicle_type: vehicleType,
          vehicle,
        }),
      );
      const created = (await service.create(
        auth,
        {
          city_id: CITY,
          vehicle_category_id: vehicleCategoryId,
          package_weight_kg: 1,
          stops: stops(),
        },
        `idem-${vehicle}`,
      )) as { vehicle_category_id: string };
      expect(orders.insertOrder).toHaveBeenCalledWith(
        expect.objectContaining({ vehicleCategoryId }),
        expect.anything(),
      );
      expect(created.vehicle_category_id).toBe(vehicleCategoryId);
    },
  );

  it.each([
    { vehicle_type: null, vehicle: null, name: 'Auto' },
    { vehicle_type: 'two_wheeler', vehicle: 'truck', name: 'Legacy truck' },
  ])(
    'rejects an active non-canonical category ($name)',
    async (row) => {
      const { service, catalog, orders, fares } = build();
      catalog.findActiveVehicleCategory.mockResolvedValue(category(row));
      await expect(
        service.create(
          auth,
          { city_id: CITY, vehicle_category_id: TRUCK, package_weight_kg: 10, stops: stops() },
          `idem-legacy-${row.name}`,
        ),
      ).rejects.toMatchObject({
        code: 'VEHICLE_CATEGORY_INVALID',
        status: 400,
      });
      expect(orders.insertOrder).not.toHaveBeenCalled();

      await expect(service.quote(auth, ORDER)).rejects.toMatchObject({
        code: 'VEHICLE_CATEGORY_INVALID',
        status: 400,
      });
      expect(fares.insertQuoteFromActiveConfig).not.toHaveBeenCalled();

      await expect(service.confirm(auth, ORDER, QUOTE)).rejects.toMatchObject({
        code: 'VEHICLE_CATEGORY_INVALID',
        status: 400,
      });
      expect(fares.insertSnapshotFromQuote).not.toHaveBeenCalled();
    },
  );

  it('rejects a package heavier than the selected vehicle', async () => {
    const { service, catalog, orders } = build();
    catalog.findActiveVehicleCategory.mockResolvedValue(
      category({ weight_capacity: '20 kg' }),
    );
    await expect(
      service.create(
        auth,
        { city_id: CITY, vehicle_category_id: TRUCK, package_weight_kg: 25, stops: stops() },
        'idem-2',
      ),
    ).rejects.toThrow('Package weight exceeds this vehicle capacity');
    expect(orders.insertOrder).not.toHaveBeenCalled();
  });

  it('stores a package that fits the selected vehicle', async () => {
    const { service, orders } = build();
    const created = (await service.create(
      auth,
      { city_id: CITY, vehicle_category_id: TRUCK, package_weight_kg: 10, stops: stops() },
      'idem-3',
    )) as { package_weight_kg: string; vehicle_category_id: string };
    expect(orders.insertOrder).toHaveBeenCalledWith(
      expect.objectContaining({ packageWeightKg: 10, vehicleCategoryId: TRUCK }),
      expect.anything(),
    );
    expect(created.package_weight_kg).toBe('10.000');
    expect(created.vehicle_category_id).toBe(TRUCK);
  });

  it('quotes the backend fare for a canonical vehicle', async () => {
    const { service, fares } = build();
    fares.insertQuoteFromActiveConfig.mockResolvedValue(quote());
    const body = (await service.quote(auth, ORDER)) as { trip_fare: string };
    expect(fares.insertQuoteFromActiveConfig).toHaveBeenCalledWith(
      expect.objectContaining({
        vehicleCategoryId: TRUCK,
        distanceKm: '12.000',
      }),
      expect.anything(),
    );
    expect(body.trip_fare).toBe('819.00');
  });

  it('snapshots the recalculated fare and ignores a mismatched quote amount', async () => {
    const { service, fares } = build();
    const confirmed = (await service.confirm(auth, ORDER, QUOTE)) as {
      fare_snapshot: { trip_fare: string; tax: string };
    };
    expect(fares.tripFareForVersion).toHaveBeenCalledWith(
      {
        fareConfigVersionId: VERSION,
        vehicleCategoryId: TRUCK,
        distanceKm: '12.000',
      },
      expect.anything(),
    );
    expect(fares.insertSnapshotFromQuote).toHaveBeenCalledWith(
      expect.objectContaining({ quoteId: QUOTE, orderId: ORDER }),
      expect.anything(),
    );
    expect(confirmed.fare_snapshot.trip_fare).toBe('819.00');
    expect(confirmed.fare_snapshot.tax).toBe('0.00');

    fares.findQuote.mockResolvedValue(quote({ trip_fare: '1.00', net_payable: '1.00' }));
    fares.tripFareForVersion.mockResolvedValue('819.00');
    fares.insertSnapshotFromQuote.mockClear();
    await expect(service.confirm(auth, ORDER, QUOTE)).rejects.toThrow(
      'Fare quote does not match the fare configuration for this route',
    );
    expect(fares.insertSnapshotFromQuote).not.toHaveBeenCalled();
  });

  it('does not confirm a quote from a different route distance', async () => {
    const { service, routing, fares } = build();
    routing.distanceKm.mockReturnValue('1.000');
    await expect(service.confirm(auth, ORDER, QUOTE)).rejects.toThrow(
      'Fare quote distance does not match this route',
    );
    expect(fares.insertSnapshotFromQuote).not.toHaveBeenCalled();
  });

  it('rejects client fare fields on preview and confirm', async () => {
    const preview = plainToInstance(PreviewVehicleFaresDto, {
      city_id: CITY,
      trip_fare: '1.00',
      distance_km: '1',
      stops: stops(),
    });
    const previewErrors = await validate(preview, {
      whitelist: true,
      forbidNonWhitelisted: true,
    });
    expect(previewErrors.map((error) => error.property)).toEqual(
      expect.arrayContaining(['trip_fare', 'distance_km']),
    );

    const confirm = plainToInstance(ConfirmOrderDto, {
      fare_quote_id: QUOTE,
      trip_fare: '1.00',
    });
    const confirmErrors = await validate(confirm, {
      whitelist: true,
      forbidNonWhitelisted: true,
    });
    expect(confirmErrors.map((error) => error.property)).toContain('trip_fare');
  });
});
