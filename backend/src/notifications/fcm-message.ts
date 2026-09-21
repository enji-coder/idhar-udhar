import { PushMessage } from './push-provider';

export type FcmMulticastMessage = {
  tokens: string[];
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: { priority: 'high' };
};

export function buildFcmData(message: PushMessage): Record<string, string> {
  return {
    notification_id: message.notificationId,
    type: message.type,
    order_id: message.orderId ?? '',
  };
}

export function buildFcmMulticastMessage(
  message: PushMessage,
  tokens: string[],
): FcmMulticastMessage {
  return {
    tokens,
    notification: {
      title: message.title,
      body: message.body,
    },
    data: buildFcmData(message),
    android: { priority: 'high' },
  };
}

export const FCM_PERMANENT_ERROR_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export function isPermanentFcmError(code: string | undefined): boolean {
  if (!code) {
    return false;
  }
  return FCM_PERMANENT_ERROR_CODES.has(code);
}
