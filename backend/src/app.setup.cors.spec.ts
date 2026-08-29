import { isAllowedCorsOrigin } from './app.setup';

describe('CORS origin allowlist', () => {
  const listed = ['https://idhar-udhar-admin.netlify.app', 'http://localhost:5173'];

  it('allows the deployed Admin origin', () => {
    expect(
      isAllowedCorsOrigin('https://idhar-udhar-admin.netlify.app', listed, 'development'),
    ).toBe(true);
  });

  it('allows loopback Admin origins when not production', () => {
    expect(isAllowedCorsOrigin('http://localhost:8888', [], 'development')).toBe(true);
    expect(isAllowedCorsOrigin('http://127.0.0.1:5173', listed, 'test')).toBe(true);
  });

  it('rejects unknown origins and does not use a wildcard', () => {
    expect(isAllowedCorsOrigin('https://evil.example', listed, 'development')).toBe(false);
  });

  it('does not allow unlisted loopback in production', () => {
    expect(isAllowedCorsOrigin('http://localhost:5173', listed, 'production')).toBe(true);
    expect(isAllowedCorsOrigin('http://localhost:9999', listed, 'production')).toBe(false);
  });
});
