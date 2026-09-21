import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository, PROVISIONAL_CUSTOMER_DISPLAY_NAME } from '../auth/identity/identity.repository';

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

  private serializeRiderDirectory(
    row: Awaited<ReturnType<IdentityRepository['listRiders']>>[number],
  ) {
    return {
      rider_profile_id: row.rider_profile_id,
      identity_id: row.identity_id,
      phone_normalized: row.phone_normalized,
      onboarding_kyc_status: row.onboarding_kyc_status,
      approval_status: row.approval_status,
      online_status: row.online_status,
      cod_operational_status: row.cod_operational_status,
      home_city_id: row.home_city_id,
      home_zone_id: row.home_zone_id,
      city_code: row.city_code,
      zone_name: row.zone_name,
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
