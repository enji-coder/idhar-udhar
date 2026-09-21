export const PUSH_PROVIDER = 'PUSH_PROVIDER';

export type PushProviderMode = 'capture' | 'unconfigured' | 'fcm';

export type PushMessage = {
  deliveryId: string;
  notificationId: string;
  identityId: string;
  profileType: 'CUSTOMER' | 'RIDER' | 'ADMIN' | null;
  type: string;
  title: string;
  body: string;
  orderId: string | null;
};

export type PushSendResult =
  | { ok: true; providerMessageId: string | null }
  | { ok: false; error: string; retryable?: boolean };

export interface PushProvider {
  readonly mode: PushProviderMode;
  send(message: PushMessage): Promise<PushSendResult>;
}
