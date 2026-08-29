export const PROFILE_ROLES = ['CUSTOMER', 'RIDER', 'ADMIN'] as const;

export type ProfileRole = (typeof PROFILE_ROLES)[number];

export type AuthContext = {
  identityId: string;
  sessionId: string;
  role: ProfileRole;
  profileId: string;
};

export type TokenPair = {
  accessToken: string;
  refreshToken: string;
  tokenType: 'Bearer';
  expiresIn: number;
  sessionId: string;
  role: ProfileRole;
};

export type SessionRow = {
  session_id: string;
  identity_id: string;
  active_profile_type: ProfileRole;
  customer_profile_id: string | null;
  rider_profile_id: string | null;
  admin_profile_id: string | null;
  refresh_token_hash: string | null;
  expires_at: Date;
  revoked_at: Date | null;
  auth_status: string;
};

export function profileIdFromRow(row: SessionRow): string {
  if (row.active_profile_type === 'CUSTOMER' && row.customer_profile_id) {
    return row.customer_profile_id;
  }
  if (row.active_profile_type === 'RIDER' && row.rider_profile_id) {
    return row.rider_profile_id;
  }
  if (row.active_profile_type === 'ADMIN' && row.admin_profile_id) {
    return row.admin_profile_id;
  }
  throw new Error('Session row is missing the matching profile id');
}
