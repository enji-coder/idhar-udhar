export type RiderProfileGapInput = {
  name?: string | null;
  email?: string | null;
  dateOfBirth?: string | null;
  vehicleCategoryName?: string | null;
  vehicleRegistration?: string | null;
  vehicleModel?: string | null;
  vehicleColor?: string | null;
  manufacturingYear?: number | null;
  drivingLicence?: string | null;
};

/**
 * Fields the rider app already requires before it leaves registration:
 * profile name, email, and date of birth; vehicle number, model, color,
 * and year; driving licence. Language and documents stay on their own flows.
 */
export function riderProfileGaps(input: RiderProfileGapInput): string[] {
  const missing: string[] = [];
  const name = input.name?.trim() ?? '';
  const email = input.email?.trim() ?? '';
  const registration = input.vehicleRegistration?.trim() ?? '';
  const model = input.vehicleModel?.trim() ?? '';
  const color = input.vehicleColor?.trim() ?? '';
  const licence = input.drivingLicence?.trim() ?? '';
  const year = input.manufacturingYear;

  if (name.length < 2) missing.push('name');
  if (!email.includes('@') || !email.includes('.')) missing.push('email');
  if (!input.dateOfBirth?.trim()) missing.push('date_of_birth');
  if (!input.vehicleCategoryName?.trim()) missing.push('vehicle_category');
  if (registration.length < 6) missing.push('vehicle_registration');
  if (!model) missing.push('vehicle_model');
  if (!color) missing.push('vehicle_color');
  if (year == null || year < 1980 || year > 2100) missing.push('vehicle_year');
  if (licence.length < 8) missing.push('driving_licence');
  return missing;
}

export function riderProfileComplete(input: RiderProfileGapInput): boolean {
  return riderProfileGaps(input).length === 0;
}
