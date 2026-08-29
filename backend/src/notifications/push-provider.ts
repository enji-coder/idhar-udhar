export const PUSH_PROVIDER = 'PUSH_PROVIDER';

export type PushMessage = {
  deliveryId: string;
  notificationId: string;
  identityId: string;
  type: string;
  title: string;
  body: string;
  orderId: string | null;
};

export type PushSendResult =
  | { ok: true; providerMessageId: string | null }
  | { ok: false; error: string };

export interface PushProvider {
  readonly mode: 'capture' | 'unconfigured';
  send(message: PushMessage): Promise<PushSendResult>;
}
