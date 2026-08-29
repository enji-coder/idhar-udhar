import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { TokenService } from './token.service';

describe('TokenService', () => {
  let tokens: TokenService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [JwtModule.register({})],
      providers: [
        TokenService,
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: (key: string) => {
              if (key !== 'jwt') {
                throw new Error(`unexpected config key ${key}`);
              }
              return {
                accessSecret: 'unit-test-jwt-access-secret-32ch',
                accessTtlSeconds: 900,
                refreshTtlSeconds: 2592000,
                issuer: 'idhar-udhar-api',
                refreshPepper: 'unit-test-refresh-pepper-32chars!',
              };
            },
          },
        },
      ],
    }).compile();
    tokens = moduleRef.get(TokenService);
  });

  it('issues a verifiable access JWT with session claims', () => {
    const jwt = tokens.issueAccessToken({
      identityId: '11111111-1111-1111-1111-111111111111',
      sessionId: '22222222-2222-2222-2222-222222222222',
      role: 'CUSTOMER',
      profileId: '33333333-3333-3333-3333-333333333333',
    });
    const claims = tokens.verifyAccessToken(jwt);
    expect(claims.sub).toBe('11111111-1111-1111-1111-111111111111');
    expect(claims.sid).toBe('22222222-2222-2222-2222-222222222222');
    expect(claims.role).toBe('CUSTOMER');
    expect(claims.pid).toBe('33333333-3333-3333-3333-333333333333');
  });

  it('hashes refresh tokens and never returns the raw value as the hash', () => {
    const generated = tokens.generateRefreshToken();
    expect(generated.hash).toBe(tokens.hashRefreshToken(generated.raw));
    expect(generated.hash).not.toBe(generated.raw);
    expect(generated.hash).toHaveLength(64);
  });

  it('rejects a tampered access token', () => {
    expect(() => tokens.verifyAccessToken('not-a-jwt')).toThrow(
      'Access token is invalid or expired',
    );
  });
});
