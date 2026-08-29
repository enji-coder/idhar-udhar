import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

export type AdminFinanceProfile = {
  admin_profile_id: string;
  role: string;
  finance_access: boolean;
};

/**
 * The existing admin finance rule, in one place so read and write paths cannot
 * drift: ADMIN role, a matching admin profile, and either SUPER_ADMIN, the
 * FINANCE role, or the finance_access flag.
 */
export async function assertAdminFinance(
  identities: IdentityRepository,
  auth: AuthContext,
): Promise<AdminFinanceProfile> {
  if (auth.role !== 'ADMIN') {
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
  }
  const profile = await identities.findAdminProfile(auth.identityId);
  if (!profile || profile.admin_profile_id !== auth.profileId) {
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin profile required', 403);
  }
  const allowed =
    profile.role === 'SUPER_ADMIN' ||
    profile.role === 'FINANCE' ||
    profile.finance_access === true;
  if (!allowed) {
    throw new ApiError(ErrorCodes.FORBIDDEN, 'Finance access is required', 403);
  }
  return {
    admin_profile_id: profile.admin_profile_id,
    role: profile.role,
    finance_access: profile.finance_access,
  };
}

/**
 * Changing tax configuration is narrower than reading a report: the
 * finance_access flag alone is not enough.
 */
export async function assertTaxConfigWriter(
  identities: IdentityRepository,
  auth: AuthContext,
): Promise<AdminFinanceProfile> {
  const profile = await assertAdminFinance(identities, auth);
  if (profile.role !== 'SUPER_ADMIN' && profile.role !== 'FINANCE') {
    throw new ApiError(
      ErrorCodes.FORBIDDEN,
      'Only SUPER_ADMIN or FINANCE may change GST configuration',
      403,
    );
  }
  return profile;
}
