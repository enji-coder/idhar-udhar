import { buildFcmData, buildFcmMulticastMessage } from './fcm-message';
import { PushMessage } from './push-provider';

const message: PushMessage = {
  deliveryId: '11111111-1111-4111-8111-111111111111',
  notificationId: '22222222-2222-4222-8222-222222222222',
  identityId: '33333333-3333-4333-8333-333333333333',
  profileType: 'CUSTOMER',
  type: 'ORDER_CONFIRMED',
  title: 'Order confirmed',
  body: 'Your order IU-AMD-0000000001 is confirmed. We are searching for a rider.',
  orderId: '44444444-4444-4444-8444-444444444444',
};

describe('FCM message mapping', () => {
  it('maps title, body, type, and order_id as string data', () => {
    const built = buildFcmMulticastMessage(message, ['token-a', 'token-b']);
    expect(built.notification).toEqual({
      title: 'Order confirmed',
      body: message.body,
    });
    expect(built.data).toEqual({
      notification_id: message.notificationId,
      type: 'ORDER_CONFIRMED',
      order_id: message.orderId,
    });
    expect(Object.values(built.data).every((value) => typeof value === 'string')).toBe(
      true,
    );
    expect(built.android.priority).toBe('high');
    expect(JSON.stringify(built)).not.toContain(message.identityId);
  });

  it('uses an empty order_id string when the inbox row has none', () => {
    expect(buildFcmData({ ...message, orderId: null }).order_id).toBe('');
  });

  it('sends rider offers as data-only messages with fare and route fields', () => {
    const built = buildFcmMulticastMessage(
      {
        ...message,
        profileType: 'RIDER',
        type: 'OFFER_NEW',
        title: 'New delivery request',
        body: 'You have a new delivery request.',
        data: {
          offer_id: '55555555-5555-4555-8555-555555555555',
          trip_fare: '500.00',
          distance_km: '12.4',
          estimated_duration_seconds: '1488',
          pickup_address: 'CG Road',
          drop_address: 'Navrangpura',
          expires_at: '2026-10-09T12:00:30.000Z',
        },
      },
      ['token-a'],
    );
    expect(built.notification).toBeUndefined();
    expect(built.data.type).toBe('OFFER_NEW');
    expect(built.data.title).toBe('New delivery request');
    expect(built.data.trip_fare).toBe('500.00');
    expect(built.data.distance_km).toBe('12.4');
    expect(built.data.offer_id).toBe('55555555-5555-4555-8555-555555555555');
    expect(built.android.priority).toBe('high');
  });
});
