import { ValidationPipe } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { UpdateRiderProfileDto } from './dto/update-rider-profile.dto';
import { ProfilesService } from './profiles.service';

const riderId = '11111111-1111-4111-8111-111111111111';
const identityId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

function riderAuth(): AuthContext {
  return {
    identityId,
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    role: 'RIDER',
    profileId: riderId,
  };
}

const storedProfile = {
  identity_id: identityId,
  rider_profile_id: riderId,
  onboarding_kyc_status: 'PENDING',
  approval_status: 'APPROVED',
  online_status: 'OFFLINE',
  home_city_id: null,
  home_zone_id: null,
  cod_operational_status: 'CLEAR',
  preferred_language: 'en',
  profile_picture_file_id: null,
};

describe('ProfilesService rider profile', () => {
  const identities = {
    findRiderProfile: jest.fn(),
    findById: jest.fn(),
    findRiderDriver: jest.fn(),
    findActiveRiderVehicle: jest.fn(),
    updateIdentityEmail: jest.fn(),
    upsertRiderDriverDetails: jest.fn(),
    updateRiderLanguage: jest.fn(),
    upsertRiderVehicle: jest.fn(),
  };
  const service = new ProfilesService(identities as unknown as IdentityRepository);

  beforeEach(() => {
    jest.clearAllMocks();
    identities.findRiderProfile.mockResolvedValue(storedProfile);
    identities.findById.mockResolvedValue({
      phone_normalized: '9876543210',
      email: 'asha@example.com',
    });
    identities.findRiderDriver.mockResolvedValue({
      name: 'Asha Patel',
      date_of_birth: '1998-04-12',
      driving_licence: 'GJ0120230001234',
    });
    identities.findActiveRiderVehicle.mockResolvedValue({
      vehicle_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      vehicle_category_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      vehicle_category_name: 'Scooty',
      registration: 'GJ01AB1234',
      model: 'Activa',
      color: 'White',
      manufacturing_year: 2022,
    });
  });

  it('returns the stored profile and vehicle category', async () => {
    const profile = await service.rider(riderAuth());
    expect(profile.name).toBe('Asha Patel');
    expect(profile.email).toBe('asha@example.com');
    expect(profile.phone_normalized).toBe('9876543210');
    expect(profile.vehicle?.vehicle_category_name).toBe('Scooty');
    expect(profile.vehicle?.registration).toBe('GJ01AB1234');
    expect(profile.profile_complete).toBe(true);
    expect(profile.missing_fields).toEqual([]);
  });

  it('reports an incomplete rider without granting completion', async () => {
    identities.findRiderDriver.mockResolvedValue({
      name: null,
      date_of_birth: null,
      driving_licence: null,
    });
    identities.findActiveRiderVehicle.mockResolvedValue(null);
    identities.findById.mockResolvedValue({
      phone_normalized: '9876543210',
      email: null,
    });
    const profile = await service.rider(riderAuth());
    expect(profile.profile_complete).toBe(false);
    expect(profile.missing_fields).toContain('name');
    expect(profile.missing_fields).toContain('vehicle_category');
    expect(profile.vehicle).toBeNull();
  });

  it('persists a profile update and returns the canonical profile', async () => {
    identities.updateIdentityEmail.mockResolvedValue(undefined);
    identities.upsertRiderDriverDetails.mockResolvedValue(undefined);
    identities.findById.mockResolvedValue({
      phone_normalized: '9876543210',
      email: 'new@example.com',
    });
    identities.findRiderDriver.mockResolvedValue({
      name: 'New Name',
      date_of_birth: '1998-04-12',
      driving_licence: 'GJ0120230001234',
    });

    const profile = await service.updateRider(riderAuth(), {
      name: 'New Name',
      email: 'new@example.com',
    });

    expect(identities.updateIdentityEmail).toHaveBeenCalledWith(
      identityId,
      'new@example.com',
    );
    expect(identities.upsertRiderDriverDetails).toHaveBeenCalledWith(
      expect.objectContaining({
        riderProfileId: riderId,
        name: 'New Name',
        updateName: true,
        updateLicence: false,
      }),
    );
    expect(profile.name).toBe('New Name');
    expect(profile.email).toBe('new@example.com');
    expect(profile.phone_normalized).toBe('9876543210');
  });
});

describe('UpdateRiderProfileDto', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  it('rejects a mobile number on profile update', async () => {
    await expect(
      pipe.transform(
        {
          name: 'New Name',
          phone_normalized: '9999999999',
        },
        { type: 'body', metatype: UpdateRiderProfileDto },
      ),
    ).rejects.toBeInstanceOf(Error);
  });

  it('accepts name without a phone field', async () => {
    const result = await pipe.transform(
      { name: 'New Name' },
      { type: 'body', metatype: UpdateRiderProfileDto },
    );
    expect(result).toMatchObject({ name: 'New Name' });
    expect(result).not.toHaveProperty('phone_normalized');
  });
});

describe('ProfilesService vehicle', () => {
  it('stores the selected category and returns it', async () => {
    const identities = {
      findRiderProfile: jest.fn(async () => storedProfile),
      findById: jest.fn(async () => ({
        phone_normalized: '9876543210',
        email: 'asha@example.com',
      })),
      findRiderDriver: jest.fn(async () => ({
        name: 'Asha Patel',
        date_of_birth: '1998-04-12',
        driving_licence: 'GJ0120230001234',
      })),
      findActiveRiderVehicle: jest.fn(async () => ({
        vehicle_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        vehicle_category_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        vehicle_category_name: 'Truck',
        registration: 'GJ01TR1234',
        model: 'LPT',
        color: 'Blue',
        manufacturing_year: 2020,
      })),
      upsertRiderVehicle: jest.fn(async () => undefined),
    };
    const service = new ProfilesService(identities as unknown as IdentityRepository);
    const profile = await service.upsertRiderVehicle(riderAuth(), {
      vehicleCategoryId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      registration: 'gj01tr1234',
      model: 'LPT',
      color: 'Blue',
      manufacturingYear: 2020,
    });
    expect(identities.upsertRiderVehicle).toHaveBeenCalledWith(
      expect.objectContaining({
        registration: 'GJ01TR1234',
        vehicleCategoryId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      }),
    );
    expect(profile.vehicle?.vehicle_category_name).toBe('Truck');
    expect(profile.profile_complete).toBe(true);
  });

  it('rejects an unknown vehicle category', async () => {
    const identities = {
      findRiderProfile: jest.fn(async () => storedProfile),
      upsertRiderVehicle: jest.fn(async () => {
        throw new Error('VEHICLE_CATEGORY_NOT_FOUND');
      }),
    };
    const service = new ProfilesService(identities as unknown as IdentityRepository);
    await expect(
      service.upsertRiderVehicle(riderAuth(), {
        vehicleCategoryId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        registration: 'GJ01TR1234',
        model: 'LPT',
        color: 'Blue',
        manufacturingYear: 2020,
      }),
    ).rejects.toBeInstanceOf(ApiError);
  });
});
