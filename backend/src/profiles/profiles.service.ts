import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isUniqueViolation } from '../common/pg-error';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository, PROVISIONAL_CUSTOMER_DISPLAY_NAME } from '../auth/identity/identity.repository';
import { riderMayGoOnline } from '../files/rider-verification';
import { riderProfileGaps } from './rider-profile-completion';

/** Admin must not show ONLINE forever after app kill / network loss. */
const RIDER_ONLINE_STALE_MS = 2 * 60 * 1000;

@Injectable()
export class ProfilesService {
  constructor(private readonly identities: IdentityRepository) {}

  async customer(auth: AuthContext) {
    if (auth.role !== 'CUSTOMER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Customer profile required', 403);
    }
    const profile = await this.identities.findCustomerProfile(auth.identityId);
    if (!profile || profile.customer_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Customer profile was not found', 404);
    }
    const identity = await this.identities.findById(auth.identityId);
    return this.serializeCustomerProfile(profile, identity?.phone_normalized);
  }

  async updateCustomer(
    auth: AuthContext,
    input: { displayName: string; email?: string },
  ) {
    if (auth.role !== 'CUSTOMER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Customer profile required', 403);
    }
    const existing = await this.identities.findCustomerProfile(auth.identityId);
    if (!existing || existing.customer_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Customer profile was not found', 404);
    }
    const displayName = input.displayName.trim();
    if (displayName.length < 2) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Display name is required',
        400,
      );
    }
    const updated = await this.identities.updateCustomerProfile({
      identityId: auth.identityId,
      customerProfileId: auth.profileId,
      displayName,
      email: input.email === undefined ? undefined : input.email.trim() || null,
      updateEmail: input.email !== undefined,
    });
    if (!updated) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Customer profile was not found', 404);
    }
    const identity = await this.identities.findById(auth.identityId);
    return this.serializeCustomerProfile(updated, identity?.phone_normalized);
  }

  /**
   * The signed-in identity owns at most one rider profile. Session profile id
   * can lag that row; self-service reads and writes follow the identity.
   */
  private async ownRiderProfile(auth: AuthContext) {
    const existing = await this.identities.findRiderProfile(auth.identityId);
    if (existing) {
      return existing;
    }
    return this.identities.ensureRiderProfile(auth.identityId);
  }

  async rider(auth: AuthContext) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider profile required', 403);
    }
    const profile = await this.ownRiderProfile(auth);
    const identity = await this.identities.findById(auth.identityId);
    const driver = await this.identities.findRiderDriver(profile.rider_profile_id);
    const vehicle = await this.identities.findActiveRiderVehicle(
      profile.rider_profile_id,
    );
    return this.serializeOwnRider({
      profile,
      phone: identity?.phone_normalized ?? null,
      email: identity?.email ?? null,
      name: driver?.name ?? null,
      dateOfBirth: driver?.date_of_birth ?? null,
      drivingLicence: driver?.driving_licence ?? null,
      vehicle,
    });
  }

  async updateRider(
    auth: AuthContext,
    input: {
      name?: string;
      email?: string | null;
      dateOfBirth?: string | null;
      preferredLanguage?: string;
      drivingLicence?: string;
    },
  ) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider profile required', 403);
    }
    const profile = await this.ownRiderProfile(auth);

    if (input.email !== undefined) {
      const email =
        input.email === null || input.email.trim() === ''
          ? null
          : input.email.trim().toLowerCase();
      try {
        await this.identities.updateIdentityEmail(auth.identityId, email);
      } catch (err) {
        if (isUniqueViolation(err, 'identities_email_unique')) {
          throw new ApiError(
            ErrorCodes.VALIDATION_ERROR,
            'Email is already in use',
            409,
          );
        }
        throw err;
      }
    }

    if (
      input.name !== undefined ||
      input.dateOfBirth !== undefined ||
      input.drivingLicence !== undefined
    ) {
      const name =
        input.name === undefined ? undefined : input.name.trim();
      if (name !== undefined && name.length < 2) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Name must be at least 2 characters',
          400,
        );
      }
      const licence =
        input.drivingLicence === undefined
          ? undefined
          : input.drivingLicence.trim().toUpperCase();
      if (licence !== undefined && licence.length < 8) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Enter a valid driving licence number',
          400,
        );
      }
      await this.identities.upsertRiderDriverDetails({
        riderProfileId: profile.rider_profile_id,
        name,
        dateOfBirth: input.dateOfBirth,
        drivingLicence: licence,
        updateName: input.name !== undefined,
        updateDob: input.dateOfBirth !== undefined,
        updateLicence: input.drivingLicence !== undefined,
      });
    }

    if (input.preferredLanguage !== undefined) {
      await this.identities.updateRiderLanguage(
        profile.rider_profile_id,
        input.preferredLanguage,
      );
    }

    return this.rider(auth);
  }

  async upsertRiderVehicle(
    auth: AuthContext,
    input: {
      vehicleCategoryId: string;
      registration: string;
      model: string;
      color: string;
      manufacturingYear: number;
    },
  ) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider profile required', 403);
    }
    const profile = await this.ownRiderProfile(auth);
    try {
      await this.identities.upsertRiderVehicle({
        riderProfileId: profile.rider_profile_id,
        vehicleCategoryId: input.vehicleCategoryId,
        registration: input.registration.trim().toUpperCase(),
        model: input.model.trim(),
        color: input.color.trim(),
        manufacturingYear: input.manufacturingYear,
      });
    } catch (err) {
      if (err instanceof Error && err.message === 'VEHICLE_CATEGORY_NOT_FOUND') {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Vehicle category was not found',
          400,
        );
      }
      throw err;
    }
    return this.rider(auth);
  }

  async setRiderLanguage(auth: AuthContext, preferredLanguage: string) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider profile required', 403);
    }
    const updated = await this.identities.updateRiderLanguage(
      auth.profileId,
      preferredLanguage,
    );
    if (!updated) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }
    return {
      preferred_language: updated.preferred_language,
      approval_status: updated.approval_status,
      online_status: updated.online_status,
    };
  }

  async setRiderAvailability(auth: AuthContext, online: boolean) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider profile required', 403);
    }
    const own = await this.ownRiderProfile(auth);
    const gate = await this.identities.findRiderGate(own.rider_profile_id);
    if (!gate) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }
    if (gate.deactivated_at) {
      throw new ApiError(ErrorCodes.RIDER_NOT_ELIGIBLE, 'Rider was not found', 409);
    }
    if (online && !riderMayGoOnline(gate.approval_status)) {
      throw new ApiError(
        ErrorCodes.RIDER_NOT_ELIGIBLE,
        'Rider is not approved to go online',
        409,
      );
    }
    const updated = await this.identities.updateRiderOnlineStatus(
      own.rider_profile_id,
      online ? 'ONLINE' : 'OFFLINE',
    );
    if (!updated) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }
    return {
      approval_status: updated.approval_status,
      online_status: updated.online_status,
    };
  }

  async admin(auth: AuthContext) {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin profile required', 403);
    }
    const profile = await this.identities.findAdminProfile(auth.identityId);
    if (!profile || profile.admin_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Admin profile was not found', 404);
    }
    return {
      identity_id: profile.identity_id,
      admin_profile_id: profile.admin_profile_id,
      email: profile.email,
      role: profile.role,
      modules: profile.modules,
      finance_access: profile.finance_access,
      payout_approve: profile.payout_approve,
      city_scope_id: profile.city_scope_id,
      active: profile.active,
    };
  }

  async assertAdmin(auth: AuthContext): Promise<void> {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
    const profile = await this.identities.findAdminProfile(auth.identityId);
    if (!profile || profile.admin_profile_id !== auth.profileId || !profile.active) {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin profile required', 403);
    }
  }

  async listRiders(auth: AuthContext) {
    await this.assertAdmin(auth);
    const rows = await this.identities.listRiders();
    return {
      riders: rows.map((row) => this.serializeRiderDirectory(row)),
    };
  }

  async getRider(auth: AuthContext, riderProfileId: string) {
    await this.assertAdmin(auth);
    const row = await this.identities.findRiderDirectory(riderProfileId);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
    }
    return this.serializeRiderDirectory(row);
  }

  async listCustomers(auth: AuthContext) {
    await this.assertAdmin(auth);
    const rows = await this.identities.listCustomers();
    return {
      customers: rows.map((row) => this.serializeCustomerDirectory(row)),
    };
  }

  async getCustomer(auth: AuthContext, customerProfileId: string) {
    await this.assertAdmin(auth);
    const row = await this.identities.findCustomerDirectory(customerProfileId);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Customer was not found', 404);
    }
    return this.serializeCustomerDirectory(row);
  }

  private serializeCustomerProfile(
    profile: {
      identity_id: string;
      customer_profile_id: string;
      display_name: string;
      email: string | null;
      invoice_email: string | null;
      status: string;
      default_city_id: string | null;
    },
    phoneNormalized: string | null | undefined,
  ) {
    const displayName = profile.display_name?.trim() ?? '';
    return {
      identity_id: profile.identity_id,
      customer_profile_id: profile.customer_profile_id,
      display_name: profile.display_name,
      email: profile.email,
      invoice_email: profile.invoice_email,
      status: profile.status,
      default_city_id: profile.default_city_id,
      phone_normalized: phoneNormalized ?? null,
      needs_profile_setup:
        displayName.length === 0 ||
        displayName === PROVISIONAL_CUSTOMER_DISPLAY_NAME,
    };
  }

  private effectiveOnlineStatus(
    onlineStatus: string,
    lastSeenAt: Date | string | null | undefined,
  ): string {
    if (onlineStatus !== 'ONLINE') {
      return onlineStatus;
    }
    if (!lastSeenAt) {
      return 'OFFLINE';
    }
    const seen =
      lastSeenAt instanceof Date ? lastSeenAt : new Date(lastSeenAt);
    if (Number.isNaN(seen.getTime())) {
      return 'OFFLINE';
    }
    if (Date.now() - seen.getTime() > RIDER_ONLINE_STALE_MS) {
      return 'OFFLINE';
    }
    return 'ONLINE';
  }

  private serializeRiderDirectory(
    row: Awaited<ReturnType<IdentityRepository['listRiders']>>[number],
  ) {
    const lastSeen =
      'last_seen_at' in row
        ? (row as { last_seen_at?: Date | string | null }).last_seen_at
        : null;
    return {
      rider_profile_id: row.rider_profile_id,
      identity_id: row.identity_id,
      phone_normalized: row.phone_normalized,
      onboarding_kyc_status: row.onboarding_kyc_status,
      approval_status: row.approval_status,
      online_status: this.effectiveOnlineStatus(row.online_status, lastSeen),
      last_seen_at: lastSeen ?? null,
      cod_operational_status: row.cod_operational_status,
      home_city_id: row.home_city_id,
      home_zone_id: row.home_zone_id,
      city_code: row.city_code,
      zone_name: row.zone_name,
      name: 'name' in row ? (row as { name?: string | null }).name ?? null : null,
      email: 'email' in row ? (row as { email?: string | null }).email ?? null : null,
      date_of_birth:
        'date_of_birth' in row
          ? (row as { date_of_birth?: string | null }).date_of_birth ?? null
          : null,
      preferred_language:
        'preferred_language' in row
          ? (row as { preferred_language?: string | null }).preferred_language ??
            null
          : null,
      has_profile_picture:
        'profile_picture_file_id' in row
          ? Boolean(
              (row as { profile_picture_file_id?: string | null })
                .profile_picture_file_id,
            )
          : false,
      ...this.vehicleAndCompletion(row),
    };
  }

  private serializeOwnRider(input: {
    profile: {
      identity_id: string;
      rider_profile_id: string;
      onboarding_kyc_status: string;
      approval_status: string;
      online_status: string;
      home_city_id: string | null;
      home_zone_id: string | null;
      cod_operational_status: string;
      preferred_language: string | null;
      profile_picture_file_id: string | null;
    };
    phone: string | null;
    email: string | null;
    name: string | null;
    dateOfBirth: string | null;
    drivingLicence: string | null;
    vehicle: {
      vehicle_id: string;
      vehicle_category_id: string;
      vehicle_category_name: string;
      registration: string | null;
      model: string | null;
      color: string | null;
      manufacturing_year: number | null;
    } | null;
  }) {
    const year = input.vehicle?.manufacturing_year ?? null;
    const gaps = riderProfileGaps({
      name: input.name,
      email: input.email,
      dateOfBirth: input.dateOfBirth,
      vehicleCategoryName: input.vehicle?.vehicle_category_name,
      vehicleRegistration: input.vehicle?.registration,
      vehicleModel: input.vehicle?.model,
      vehicleColor: input.vehicle?.color,
      manufacturingYear: year,
      drivingLicence: input.drivingLicence,
    });
    return {
      identity_id: input.profile.identity_id,
      rider_profile_id: input.profile.rider_profile_id,
      onboarding_kyc_status: input.profile.onboarding_kyc_status,
      approval_status: input.profile.approval_status,
      online_status: input.profile.online_status,
      home_city_id: input.profile.home_city_id,
      home_zone_id: input.profile.home_zone_id,
      cod_operational_status: input.profile.cod_operational_status,
      phone_normalized: input.phone,
      email: input.email,
      name: input.name,
      date_of_birth: input.dateOfBirth,
      preferred_language: input.profile.preferred_language ?? null,
      has_profile_picture: Boolean(input.profile.profile_picture_file_id),
      driving_licence: input.drivingLicence,
      vehicle: input.vehicle
        ? {
            vehicle_id: input.vehicle.vehicle_id,
            vehicle_category_id: input.vehicle.vehicle_category_id,
            vehicle_category_name: input.vehicle.vehicle_category_name,
            registration: input.vehicle.registration,
            model: input.vehicle.model,
            color: input.vehicle.color,
            manufacturing_year: year,
          }
        : null,
      profile_complete: gaps.length === 0,
      missing_fields: gaps,
    };
  }

  private vehicleAndCompletion(row: {
    name?: string | null;
    email?: string | null;
    date_of_birth?: string | null;
    driving_licence?: string | null;
    vehicle_category_id?: string | null;
    vehicle_category_name?: string | null;
    vehicle_registration?: string | null;
    vehicle_model?: string | null;
    vehicle_color?: string | null;
    manufacturing_year?: number | string | null;
  }) {
    const year =
      row.manufacturing_year == null || row.manufacturing_year === ''
        ? null
        : Number(row.manufacturing_year);
    const gaps = riderProfileGaps({
      name: row.name,
      email: row.email,
      dateOfBirth: row.date_of_birth,
      vehicleCategoryName: row.vehicle_category_name,
      vehicleRegistration: row.vehicle_registration,
      vehicleModel: row.vehicle_model,
      vehicleColor: row.vehicle_color,
      manufacturingYear: Number.isFinite(year) ? year : null,
      drivingLicence: row.driving_licence,
    });
    return {
      driving_licence: row.driving_licence ?? null,
      vehicle_category_id: row.vehicle_category_id ?? null,
      vehicle_category_name: row.vehicle_category_name ?? null,
      vehicle_registration: row.vehicle_registration ?? null,
      vehicle_model: row.vehicle_model ?? null,
      vehicle_color: row.vehicle_color ?? null,
      manufacturing_year: Number.isFinite(year) ? year : null,
      profile_complete: gaps.length === 0,
      missing_fields: gaps,
    };
  }

  private serializeCustomerDirectory(
    row: Awaited<ReturnType<IdentityRepository['listCustomers']>>[number],
  ) {
    return {
      customer_profile_id: row.customer_profile_id,
      identity_id: row.identity_id,
      display_name: row.display_name,
      email: row.email,
      invoice_email: row.invoice_email,
      status: row.status,
      phone_normalized: row.phone_normalized,
      default_city_id: row.default_city_id,
      city_code: row.city_code,
    };
  }
}
