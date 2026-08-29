import 'api_client.dart';
import 'json_codec.dart';
import 'token_store.dart';

enum MarketplaceActor { customer, rider }

extension MarketplaceActorX on MarketplaceActor {
  String get apiValue => this == MarketplaceActor.customer ? 'CUSTOMER' : 'RIDER';
}

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.sessionId,
    required this.role,
    this.identityId,
    this.profileId,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String sessionId;
  final String role;
  final String? identityId;
  final String? profileId;

  factory TokenPair.fromJson(Map<String, Object?> json) {
    return TokenPair(
      accessToken: jsonString(json['access_token']) ?? '',
      refreshToken: jsonString(json['refresh_token']) ?? '',
      expiresIn: jsonInt(json['expires_in']),
      sessionId: jsonString(json['session_id']) ?? '',
      role: jsonString(json['role']) ?? '',
      identityId: jsonString(json['identity_id']),
      profileId: jsonString(json['profile_id']),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.identityId,
    required this.sessionId,
    required this.role,
    required this.profileId,
  });

  final String identityId;
  final String sessionId;
  final String role;
  final String profileId;

  factory AuthSession.fromJson(Map<String, Object?> json) {
    return AuthSession(
      identityId: jsonString(json['identity_id']) ?? '',
      sessionId: jsonString(json['session_id']) ?? '',
      role: jsonString(json['role']) ?? '',
      profileId: jsonString(json['profile_id']) ?? '',
    );
  }
}

class AuthApi {
  AuthApi(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  Future<void> requestOtp({
    required String phone,
    required MarketplaceActor actor,
  }) async {
    await _client.post(
      '/v1/auth/otp/request',
      data: <String, String>{
        'phone': _digits(phone),
        'actor_type': actor.apiValue,
      },
    );
  }

  Future<TokenPair> verifyOtp({
    required String phone,
    required MarketplaceActor actor,
    required String code,
  }) async {
    final Map<String, Object?> body = await _client.post(
      '/v1/auth/otp/verify',
      data: <String, String>{
        'phone': _digits(phone),
        'actor_type': actor.apiValue,
        'code': code.replaceAll(RegExp(r'\D'), ''),
      },
    );
    final TokenPair pair = TokenPair.fromJson(body);
    await _tokens.save(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      role: pair.role,
      phone: _digits(phone),
    );
    return pair;
  }

  Future<AuthSession> session() async {
    return AuthSession.fromJson(await _client.get('/v1/auth/session'));
  }

  Future<void> logout() async {
    try {
      await _client.post('/v1/auth/logout');
    } catch (_) {
      // Local clear still happens; revoked-or-expired is equivalent.
    }
    await _tokens.clear();
  }

  String _digits(String phone) {
    final String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits;
  }
}
