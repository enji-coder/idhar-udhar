import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { CreateVehicleCategoryDto } from './dto/create-vehicle-category.dto';
import { UpdateVehicleCategoryDto } from './dto/update-vehicle-category.dto';
import { VehicleCategoriesService } from './vehicle-categories.service';
import { VehicleCategoryRow } from './vehicle-categories.repository';

const auth: AuthContext = {
  identityId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  sessionId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
  role: 'ADMIN',
  profileId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
};

const CATEGORY_ID = '11111111-1111-4111-8111-111111111111';

function row(overrides: Partial<VehicleCategoryRow> = {}): VehicleCategoryRow {
  return {
    vehicle_category_id: CATEGORY_ID,
    code: null,
    name: 'Bike',
    active: true,
    weight_capacity: '20',
    size: '36cm',
    vehicle_type: 'two_wheeler',
    vehicle: 'bike',
    created_at: new Date('2026-09-01T00:00:00.000Z'),
    updated_at: new Date('2026-09-01T00:00:00.000Z'),
    base_fare: '40.00',
    per_km: '8.00',
    initial_minimum: '30.00',
    waiting: '1.00',
    initial_waiting_minutes: 0,
    waiting_charge_per_minute: '0.00',
    surge: '2.00',
    toll: '3.00',
    parking: '4.00',
    rider_percentage: '80.00',
    company_commission_percentage: '20.00',
    fare_config_version_id: '22222222-2222-4222-8222-222222222222',
    ...overrides,
  };
}

function serviceFor(stored: VehicleCategoryRow | null = null) {
  let current = stored;
  const categories = {
    findByName: jest.fn(async () => null),
    insert: jest.fn(async (input: { name: string; vehicle_type: string | null; vehicle: string | null }) => {
      current = row({
        name: input.name,
        vehicle_type: input.vehicle_type,
        vehicle: input.vehicle,
      });
      return { vehicle_category_id: CATEGORY_ID };
    }),
    update: jest.fn(async (_id: string, input: Partial<VehicleCategoryRow>) => {
      current = row({ ...current, ...input });
    }),
    findById: jest.fn(async () => current),
    usage: jest.fn(async () => ({
      vehicles: 0,
      orders: 0,
      fare_quotes: 0,
      fare_snapshots: 0,
      fare_rates: 0,
    })),
    delete: jest.fn(),
    list: jest.fn(),
    usageByCategory: jest.fn(),
  };
  const fares = {
    publishCategoryRates: jest.fn(async () => '22222222-2222-4222-8222-222222222222'),
  };
  const postgres = {
    transaction: jest.fn(async (work: (db: object) => Promise<unknown>) => work({})),
  };
  return {
    service: new VehicleCategoriesService(
      categories as never,
      fares as never,
      postgres as never,
    ),
    categories,
    fares,
  };
}

const rates = {
  base_fare: 40,
  per_km: 8,
  initial_minimum: 30,
  waiting: 1,
  surge: 2,
  toll: 3,
  parking: 4,
  rider_percentage: 80,
  company_commission_percentage: 20,
};

describe('vehicle category configuration', () => {
  it('stores a valid vehicle pair and publishes the existing fare rates', async () => {
    const { service, categories, fares } = serviceFor();
    const body: CreateVehicleCategoryDto = {
      name: 'Bike',
      vehicle_type: 'two_wheeler',
      vehicle: 'bike',
      weight_capacity: '20',
      size: '36cm',
      rates,
    };
    const created = await service.create(auth, body);
    expect(categories.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        name: 'Bike',
        vehicle_type: 'two_wheeler',
        vehicle: 'bike',
        weight_capacity: '20',
        size: '36cm',
      }),
      expect.anything(),
    );
    expect(fares.publishCategoryRates).toHaveBeenCalledWith(
      expect.objectContaining({
        base_fare: '40.00',
        per_km: '8.00',
        initial_minimum: '30.00',
        waiting: '1.00',
        surge: '2.00',
        toll: '3.00',
        parking: '4.00',
        rider_percentage: '80.00',
        company_commission_percentage: '20.00',
      }),
      expect.anything(),
    );
    expect(created.vehicle_type).toBe('two_wheeler');
    expect(created.vehicle).toBe('bike');
    expect(created.rates.base_fare).toBe('40.00');
    expect(created.rates.company_commission_percentage).toBe('20.00');
  });

  it('keeps a name-only category outside the hierarchy', async () => {
    const { service, categories } = serviceFor();
    await service.create(auth, { name: 'E2E Bike 1' });
    expect(categories.insert).toHaveBeenCalledWith(
      expect.objectContaining({ vehicle_type: null, vehicle: null, name: 'E2E Bike 1' }),
      expect.anything(),
    );
  });

  it.each([
    ['two_wheeler', 'tempo'],
    ['two_wheeler', 'truck'],
    ['three_wheeler', 'bike'],
    ['truck', 'bike'],
  ] as const)('rejects %s / %s before insert', async (vehicleType, vehicle) => {
    const { service, categories } = serviceFor();
    await expect(
      service.create(auth, { name: 'Bad', vehicle_type: vehicleType, vehicle }),
    ).rejects.toBeInstanceOf(ApiError);
    expect(categories.insert).not.toHaveBeenCalled();
  });

  it('rejects a split that does not total 100', async () => {
    const { service, fares } = serviceFor();
    await expect(
      service.create(auth, {
        name: 'Bike',
        vehicle_type: 'two_wheeler',
        vehicle: 'bike',
        rates: { rider_percentage: 90, company_commission_percentage: 15 },
      }),
    ).rejects.toMatchObject({
      status: 400,
      message: 'Rider percentage and company commission must add up to 100',
    });
    expect(fares.publishCategoryRates).not.toHaveBeenCalled();
  });

  it('rejects a negative weight capacity', async () => {
    const { service, categories } = serviceFor();
    await expect(
      service.create(auth, {
        name: 'Bike',
        vehicle_type: 'two_wheeler',
        vehicle: 'bike',
        weight_capacity: '-5',
      }),
    ).rejects.toMatchObject({ message: 'Weight capacity must be 0 or more' });
    expect(categories.insert).not.toHaveBeenCalled();
  });

  it('updates the vehicle inside the same type and keeps an omitted hierarchy', async () => {
    const existing = row();
    const { service, categories } = serviceFor(existing);
    const body: UpdateVehicleCategoryDto = {
      vehicle_type: 'two_wheeler',
      vehicle: 'scooty',
      name: 'Scooty',
    };
    const updated = await service.update(auth, CATEGORY_ID, body);
    expect(updated.vehicle).toBe('scooty');
    expect(updated.vehicle_type).toBe('two_wheeler');

    await service.update(auth, CATEGORY_ID, { active: false });
    expect(categories.update).toHaveBeenLastCalledWith(
      CATEGORY_ID,
      expect.objectContaining({
        vehicle_type: 'two_wheeler',
        vehicle: 'scooty',
        active: false,
      }),
      expect.anything(),
    );
  });

  it('rejects a vehicle that does not belong to the stored type', async () => {
    const { service, categories } = serviceFor(row());
    await expect(
      service.update(auth, CATEGORY_ID, { vehicle: 'tempo' }),
    ).rejects.toMatchObject({
      message: 'Vehicle does not belong to the selected vehicle type',
    });
    expect(categories.update).not.toHaveBeenCalled();
  });
});
