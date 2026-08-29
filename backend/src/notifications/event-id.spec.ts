import { notificationIdFromEventKey, uuidv5, NOTIFICATION_NAMESPACE } from './event-id';

describe('notification event id', () => {
  it('returns a UUID v5', () => {
    const id = notificationIdFromEventKey('order:abc:ORDER_CONFIRMED:CUSTOMER:1');
    expect(id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    );
  });

  it('is deterministic for the same event key', () => {
    const key = 'payment:txn-1:PAYMENT_SUCCESSFUL';
    expect(notificationIdFromEventKey(key)).toBe(notificationIdFromEventKey(key));
  });

  it('differs for different event keys', () => {
    expect(notificationIdFromEventKey('a')).not.toBe(notificationIdFromEventKey('b'));
  });

  it('uses the project namespace', () => {
    expect(uuidv5('same', NOTIFICATION_NAMESPACE)).toBe(
      notificationIdFromEventKey('same'),
    );
  });
});
