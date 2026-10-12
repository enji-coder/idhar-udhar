import { PushMessage } from './push-provider';

export type FcmMulticastMessage = {
  tokens: string[];
  notification?: { title: string; body: string };
  data: Record<string, string>;
  android: { priority: 'high' };
};

export function buildFcmData(message: PushMessage): Record<string, string> {
  const extra = message.data ?? {};
  const data: Record<string, string> = {
    notification_id: message.notificationId,
    type: message.type,
    order_id: message.orderId ?? '',
  };
  for (const [key, value] of Object.entries(extra)) {
    if (key === 'notification_id' || key === 'type' || key === 'order_id') {
      continue;
    }
    data[key] = value;
  }
  return data;
}

export function buildFcmMulticastMessage(
  message: PushMessage,
  tokens: string[],
): FcmMulticastMessage {
  const data = buildFcmData(message);
  if (message.type === 'OFFER_NEW') {
    data.title = message.title;
    data.body = message.body;
    return {
      tokens,
      data,
      android: { priority: 'high' },
    };
  }
  return {
    tokens,
    notification: {
      title: message.title,
      body: message.body,
    },
    data,
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
