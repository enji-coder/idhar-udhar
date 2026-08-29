import { PasswordService } from './password.service';

describe('PasswordService', () => {
  const passwords = new PasswordService();

  it('hashes with Argon2id and never stores plaintext', async () => {
    const plain = 'AdminPass#2026!!';
    const hash = await passwords.hash(plain);
    expect(hash).toMatch(/^\$argon2id\$/);
    expect(hash).not.toContain(plain);
    expect(await passwords.verify(hash, plain)).toBe(true);
    expect(await passwords.verify(hash, 'wrong-password')).toBe(false);
  });
});
