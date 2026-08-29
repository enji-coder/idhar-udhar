import { canonicalJson, hashRequest } from './idempotency.repository';

describe('idempotency request hash', () => {
  it('hashes canonical JSON so key order does not change the digest', () => {
    const left = hashRequest({ city_id: 'a', stops: [{ sequence: 0 }] });
    const right = hashRequest({ stops: [{ sequence: 0 }], city_id: 'a' });
    expect(left).toBe(right);
    expect(left).toHaveLength(64);
    expect(canonicalJson({ b: 1, a: 2 })).toBe('{"a":2,"b":1}');
  });
});
