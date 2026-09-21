import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { OtpHashService } from './otp-hash.service';

describe('OtpHashService', () => {
  let hashes: OtpHashService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        OtpHashService,
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: () => ({
              length: 4,
              pepper: 'unit-test-otp-pepper-min-32-chars!!',
            }),
          },
        },
      ],
    }).compile();
    hashes = moduleRef.get(OtpHashService);
  });

  it('generates a numeric code of configured length', () => {
    const code = hashes.generateCode();
    expect(code).toMatch(/^\d{4}$/);
  });

  it('stores a hash that is not the plaintext code', () => {
    const code = '1234';
    const hash = hashes.hash('9876543210', code);
    expect(hash).not.toBe(code);
    expect(hash).toHaveLength(64);
    expect(hashes.matches('9876543210', code, hash)).toBe(true);
    expect(hashes.matches('9876543210', '0000', hash)).toBe(false);
  });
});
