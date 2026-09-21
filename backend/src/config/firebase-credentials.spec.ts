import { parseFirebaseServiceAccountJson } from './firebase-credentials';

describe('parseFirebaseServiceAccountJson', () => {
  it('rejects missing JSON without echoing secrets', () => {
    expect(() => parseFirebaseServiceAccountJson(undefined)).toThrow(
      /FIREBASE_SERVICE_ACCOUNT_JSON/,
    );
  });

  it('rejects invalid JSON without returning the raw value', () => {
    expect(() => parseFirebaseServiceAccountJson('{not-json')).toThrow(
      /valid JSON/,
    );
    try {
      parseFirebaseServiceAccountJson('{not-json');
    } catch (err) {
      expect(String(err)).not.toContain('{not-json');
    }
  });

  it('accepts a service-account object with project_id, client_email, and private_key', () => {
    const parsed = parseFirebaseServiceAccountJson(
      JSON.stringify({
        project_id: 'idhar-udhar-5dd89',
        client_email: 'sdk@idhar-udhar-5dd89.iam.gserviceaccount.com',
        private_key: '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n',
      }),
    );
    expect(parsed.project_id).toBe('idhar-udhar-5dd89');
  });
});
