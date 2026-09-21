import { getApps, initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { parseFirebaseServiceAccountJson } from '../config/firebase-credentials';
import { FcmMessaging } from './fcm-push.provider';

export function createFirebaseMessaging(): FcmMessaging {
  const account = parseFirebaseServiceAccountJson(
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
  );
  if (getApps().length === 0) {
    initializeApp({
      credential: cert({
        projectId: account.project_id,
        clientEmail: account.client_email,
        privateKey: account.private_key,
      }),
    });
  }
  return getMessaging();
}
