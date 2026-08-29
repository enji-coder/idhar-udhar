import { TokenPair } from './types/auth-context';

export function tokenPairResponse(pair: TokenPair) {
  return {
    access_token: pair.accessToken,
    refresh_token: pair.refreshToken,
    token_type: pair.tokenType,
    expires_in: pair.expiresIn,
    session_id: pair.sessionId,
    role: pair.role,
  };
}
