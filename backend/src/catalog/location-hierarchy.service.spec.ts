import { AuthContext } from '../auth/types/auth-context';
import { StatesService } from './states.service';
import { CitiesService } from './cities.service';
import { ZonesService } from './zones.service';

const auth: AuthContext = {
  identityId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  sessionId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
  role: 'ADMIN',
  profileId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
};

const STATE_ID = '11111111-1111-4111-8111-111111111111';
const CITY_ID = '22222222-2222-4222-8222-222222222222';
const ZONE_ID = '33333333-3333-4333-8333-333333333333';

describe('State → City → Zone admin catalog', () => {
  it('creates a state with a unique uppercase code', async () => {
    const states = {
      list: jest.fn(),
      findById: jest.fn(async (id: string) =>
        id === STATE_ID
          ? {
              state_id: STATE_ID,
              name: 'Gujarat',
              code: 'GJ',
              active: true,
              created_at: new Date('2026-10-01T00:00:00.000Z'),
            }
          : null,
      ),
      findByCode: jest.fn(async () => null),
      insert: jest.fn(async () => ({ state_id: STATE_ID })),
      update: jest.fn(),
    };
    const service = new StatesService(states as never);
    const body = await service.create(auth, {
      name: ' Gujarat ',
      code: 'gj',
      active: true,
    });
    expect(states.insert).toHaveBeenCalledWith({
      name: 'Gujarat',
      code: 'GJ',
      active: true,
    });
    expect(body.code).toBe('GJ');
  });

  it('rejects a duplicate state code', async () => {
    const states = {
      list: jest.fn(),
      findById: jest.fn(),
      findByCode: jest.fn(async () => ({
        state_id: STATE_ID,
        name: 'Gujarat',
        code: 'GJ',
        active: true,
        created_at: new Date(),
      })),
      insert: jest.fn(),
      update: jest.fn(),
    };
    const service = new StatesService(states as never);
    await expect(
      service.create(auth, { name: 'Other', code: 'GJ' }),
    ).rejects.toMatchObject({ code: 'STATE_CODE_TAKEN' });
    expect(states.insert).not.toHaveBeenCalled();
  });

  it('creates a city under an active state', async () => {
    const states = {
      findById: jest.fn(async () => ({
        state_id: STATE_ID,
        name: 'Gujarat',
        code: 'GJ',
        active: true,
        created_at: new Date(),
      })),
    };
    const cities = {
      list: jest.fn(),
      findById: jest.fn(async () => ({
        city_id: CITY_ID,
        state_id: STATE_ID,
        state_code: 'GJ',
        state_name: 'Gujarat',
        name: 'Ahmedabad',
        city_code: 'AMD',
        active: true,
        created_at: new Date(),
      })),
      findByCode: jest.fn(async () => null),
      insert: jest.fn(async () => ({ city_id: CITY_ID })),
      update: jest.fn(),
    };
    const service = new CitiesService(cities as never, states as never);
    const body = await service.create(auth, {
      state_id: STATE_ID,
      name: 'Ahmedabad',
      city_code: 'amd',
    });
    expect(cities.insert).toHaveBeenCalledWith({
      stateId: STATE_ID,
      name: 'Ahmedabad',
      cityCode: 'AMD',
      active: true,
    });
    expect(body.city_code).toBe('AMD');
    expect(body.state_id).toBe(STATE_ID);
  });

  it('creates a zone under a real city_id (not launch AMD hardcode)', async () => {
    const cities = {
      findById: jest.fn(async () => ({
        city_id: CITY_ID,
        state_id: STATE_ID,
        state_code: 'GJ',
        state_name: 'Gujarat',
        name: 'Ahmedabad',
        city_code: 'AMD',
        active: true,
        created_at: new Date(),
      })),
    };
    const zones = {
      list: jest.fn(),
      findById: jest.fn(async () => ({
        zone_id: ZONE_ID,
        city_id: CITY_ID,
        city_code: 'AMD',
        city_name: 'Ahmedabad',
        state_id: STATE_ID,
        state_code: 'GJ',
        state_name: 'Gujarat',
        name: 'Navrangpura',
        active: true,
        created_at: new Date(),
        rider_count: 0,
      })),
      findByName: jest.fn(async () => null),
      insert: jest.fn(async () => ({ zone_id: ZONE_ID })),
      update: jest.fn(),
      riderCount: jest.fn(),
      delete: jest.fn(),
    };
    const service = new ZonesService(zones as never, cities as never);
    const body = await service.create(auth, {
      city_id: CITY_ID,
      name: 'Navrangpura',
    });
    expect(zones.insert).toHaveBeenCalledWith({
      cityId: CITY_ID,
      name: 'Navrangpura',
      active: true,
    });
    expect(body.city_id).toBe(CITY_ID);
    expect(body.state_id).toBe(STATE_ID);
  });
});
