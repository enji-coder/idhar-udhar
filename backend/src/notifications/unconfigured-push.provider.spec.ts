import { UnconfiguredPushProvider } from './unconfigured-push.provider';
import { AppLogger } from '../common/logger/app-logger';

describe('UnconfiguredPushProvider', () => {
  it('fails honestly without pretending FCM delivered', async () => {
    const logger = { warn: jest.fn(), error: jest.fn(), info: jest.fn() };
    const provider = new UnconfiguredPushProvider(logger as unknown as AppLogger);
    const result = await provider.send({
      deliveryId: 'd1',
      notificationId: 'n1',
      identityId: 'i1',
      profileType: 'CUSTOMER',
      type: 'ORDER_CONFIRMED',
      title: 't',
      body: 'b',
      orderId: null,
    });
    expect(result).toEqual({
      ok: false,
      error: 'push provider is not configured',
      retryable: false,
    });
    expect(JSON.stringify(logger.warn.mock.calls)).not.toContain('BEGIN PRIVATE KEY');
  });
});
