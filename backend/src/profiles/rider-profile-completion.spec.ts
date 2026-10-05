import { riderProfileComplete, riderProfileGaps } from './rider-profile-completion';

const complete = {
  name: 'Asha Patel',
  email: 'asha@example.com',
  dateOfBirth: '1998-04-12',
  vehicleCategoryName: 'Scooty',
  vehicleRegistration: 'GJ01AB1234',
  vehicleModel: 'Activa',
  vehicleColor: 'White',
  manufacturingYear: 2022,
  drivingLicence: 'GJ0120230001234',
};

describe('rider profile completion', () => {
  it('treats a fully stored registration as complete', () => {
    expect(riderProfileGaps(complete)).toEqual([]);
    expect(riderProfileComplete(complete)).toBe(true);
  });

  it('lists each missing required field and does not treat nulls as complete', () => {
    expect(
      riderProfileGaps({
        name: null,
        email: null,
        dateOfBirth: null,
        vehicleCategoryName: null,
        vehicleRegistration: null,
        vehicleModel: null,
        vehicleColor: null,
        manufacturingYear: null,
        drivingLicence: null,
      }),
    ).toEqual([
      'name',
      'email',
      'date_of_birth',
      'vehicle_category',
      'vehicle_registration',
      'vehicle_model',
      'vehicle_color',
      'vehicle_year',
      'driving_licence',
    ]);
  });

  it('keeps the stored category name, including Scooty', () => {
    expect(
      riderProfileGaps({ ...complete, vehicleCategoryName: 'Scooty' }),
    ).not.toContain('vehicle_category');
  });
});
