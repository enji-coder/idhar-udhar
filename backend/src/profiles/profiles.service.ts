import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { isUniqueViolation } from '../common/pg-error';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository, PROVISIONAL_CUSTOMER_DISPLAY_NAME } from '../auth/identity/identity.repository';
import { riderMayGoOnline } from '../files/rider-verification';

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

  async rider(auth: AuthContext) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider profile required', 403);
    }
    const profile = await this.identities.findRiderProfile(auth.identityId);
    if (!profile || profile.rider_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }
    const identity = await this.identities.findById(auth.identityId);
    const driver = await this.identities.findRiderDriver(profile.rider_profile_id);
    return {
      identity_id: profile.identity_id,
      rider_profile_id: profile.rider_profile_id,
      onboarding_kyc_status: profile.onboarding_kyc_status,
      approval_status: profile.approval_status,
      online_status: profile.online_status,
      home_city_id: profile.home_city_id,
      home_zone_id: profile.home_zone_id,
      cod_operational_status: profile.cod_operational_status,
      phone_normalized: identity?.phone_normalized ?? null,
      email: identity?.email ?? null,
      name: driver?.name ?? null,
      date_of_birth: driver?.date_of_birth ?? null,
      preferred_language: profile.preferred_language ?? null,
      has_profile_picture: Boolean(profile.profile_picture_file_id),
    };
  }

  async updateRider(
    auth: AuthContext,
    input: {
      name?: string;
      email?: string | null;
      dateOfBirth?: string | null;
      preferredLanguage?: string;
    },
  ) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider profile required', 403);
    }
    const profile = await this.identities.findRiderProfile(auth.identityId);
    if (!profile || profile.rider_profile_id !== auth.profileId) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider profile was not found', 404);
    }

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

    if (input.name !== undefined || input.dateOfBirth !== undefined) {
      const name =
        input.name === undefined ? undefined : input.name.trim();
      if (name !== undefined && name.length < 2) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Name must be at least 2 characters',
          400,
        );
      }
      await this.identities.upsertRiderDriverDetails({
        riderProfileId: auth.profileId,
        name,
        dateOfBirth: input.dateOfBirth,
        updateName: input.name !== undefined,
        updateDob: input.dateOfBirth !== undefined,
      });
    }

    if (input.preferredLanguage !== undefined) {
      await this.identities.updateRiderLanguage(
        auth.profileId,
        input.preferredLanguage,
      );
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
    const gate = await this.identities.findRiderGate(auth.profileId);
    if (!gate || gate.rider_profile_id !== auth.profileId) {
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
      auth.profileId,
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
