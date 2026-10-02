import { AuthContext } from '../auth/types/auth-context';
import { CitiesService } from './cities.service';
import { StatesService } from './states.service';

const auth: AuthContext = {
  identityId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  sessionId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
  role: 'ADMIN',
  profileId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
};

const STATE_ID = '11111111-1111-4111-8111-111111111111';
const CITY_ID = '22222222-2222-4222-8222-222222222222';

describe('Stage B states and cities foundation', () => {
  it('lists Gujarat without hardcoding production UUIDs', async () => {
    const states = {
      list: jest.fn(async () => [
        {
          state_id: STATE_ID,
          name: 'Gujarat',
          code: 'GJ',
          active: true,
          created_at: new Date('2026-10-01T00:00:00.000Z'),
        },
      ]),
      findById: jest.fn(),
      findByCode: jest.fn(),
    };
    const service = new StatesService(states as never);
    const body = await service.list(auth);
    expect(body.states).toHaveLength(1);
    expect(body.states[0]).toMatchObject({
      name: 'Gujarat',
      code: 'GJ',
      active: true,
    });
    expect(body.states[0].state_id).toBe(STATE_ID);
  });

  it('lists cities with their owning state', async () => {
    const cities = {
      list: jest.fn(async () => [
        {
          city_id: CITY_ID,
          state_id: STATE_ID,
          state_code: 'GJ',
          state_name: 'Gujarat',
          name: 'Ahmedabad',
          city_code: 'AMD',
          active: true,
          created_at: new Date('2026-10-01T00:00:00.000Z'),
        },
      ]),
      findById: jest.fn(),
    };
    const service = new CitiesService(cities as never, {} as never);
    const body = await service.list(auth);
    expect(body.cities).toHaveLength(1);
    expect(body.cities[0]).toMatchObject({
      name: 'Ahmedabad',
      city_code: 'AMD',
      state_code: 'GJ',
      state_name: 'Gujarat',
      state_id: STATE_ID,
    });
  });

  it('rejects an unknown city id', async () => {
    const cities = {
      list: jest.fn(),
      findById: jest.fn(async () => null),
    };
    const service = new CitiesService(cities as never, {} as never);
    await expect(service.get(auth, CITY_ID)).rejects.toMatchObject({
      code: 'CITY_INVALID',
    });
  });
});
