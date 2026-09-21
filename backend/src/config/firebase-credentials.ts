export type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

export function parseFirebaseServiceAccountJson(
  raw: string | null | undefined,
): FirebaseServiceAccount {
  if (!raw || raw.trim().length === 0) {
    throw new Error(
      'PUSH_PROVIDER=fcm requires FIREBASE_SERVICE_ACCOUNT_JSON; refusing to fall back to capture or unconfigured',
    );
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON must be valid JSON');
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON must be a service-account object');
  }
  const record = parsed as Record<string, unknown>;
  const projectId = typeof record.project_id === 'string' ? record.project_id.trim() : '';
  const clientEmail =
    typeof record.client_email === 'string' ? record.client_email.trim() : '';
  const privateKey =
    typeof record.private_key === 'string' ? record.private_key : '';
  if (!projectId || !clientEmail || !privateKey.includes('BEGIN PRIVATE KEY')) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT_JSON is missing project_id, client_email, or private_key',
    );
  }
  return {
    project_id: projectId,
    client_email: clientEmail,
    private_key: privateKey,
  };
}
