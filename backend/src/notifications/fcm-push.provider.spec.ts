import { AppLogger } from '../common/logger/app-logger';
import { DeviceTokensRepository } from './device-tokens.repository';
import { FcmMessaging, FcmPushProvider } from './fcm-push.provider';
import { PushMessage } from './push-provider';

const identityId = '33333333-3333-4333-8333-333333333333';
const tokenA = 'fcm-token-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const tokenB = 'fcm-token-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const message: PushMessage = {
  deliveryId: '11111111-1111-4111-8111-111111111111',
  notificationId: '22222222-2222-4222-8222-222222222222',
  identityId,
  profileType: 'CUSTOMER',
  type: 'ORDER_CONFIRMED',
  title: 'Order confirmed',
  body: 'Your order is confirmed.',
  orderId: '44444444-4444-4444-8444-444444444444',
};

describe('FcmPushProvider', () => {
  const logger = {
    error: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
  } as unknown as AppLogger;

  const tokens = {
    listActive: jest.fn(),
    deactivateByIds: jest.fn(),
  };

  const messaging: FcmMessaging = {
    sendEachForMulticast: jest.fn(),
  };

  const provider = new FcmPushProvider(
    logger,
    tokens as unknown as DeviceTokensRepository,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    provider.useMessagingFactory(() => messaging);
    tokens.deactivateByIds.mockResolvedValue(1);
  });

  it('sends to every active device token and records partial success', async () => {
    tokens.listActive.mockResolvedValue([
      { push_device_token_id: 'id-a', fcm_token: tokenA },
      { push_device_token_id: 'id-b', fcm_token: tokenB },
    ]);
    (messaging.sendEachForMulticast as jest.Mock).mockResolvedValue({
      successCount: 2,
      failureCount: 0,
      responses: [
        { success: true, messageId: 'projects/x/messages/1' },
        { success: true, messageId: 'projects/x/messages/2' },
      ],
    });
    const result = await provider.send(message);
    expect(result).toEqual({
      ok: true,
      providerMessageId: 'projects/x/messages/1',
    });
    expect(messaging.sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({
        tokens: [tokenA, tokenB],
        notification: { title: message.title, body: message.body },
      }),
    );
    expect(tokens.deactivateByIds).not.toHaveBeenCalled();
  });

  it('deactivates invalid tokens and still succeeds when another token delivers', async () => {
    tokens.listActive.mockResolvedValue([
      { push_device_token_id: 'id-a', fcm_token: tokenA },
      { push_device_token_id: 'id-b', fcm_token: tokenB },
    ]);
    (messaging.sendEachForMulticast as jest.Mock).mockResolvedValue({
      successCount: 1,
      failureCount: 1,
      responses: [
        {
          success: false,
          error: { code: 'messaging/registration-token-not-registered' },
        },
        { success: true, messageId: 'projects/x/messages/2' },
      ],
    });
    const result = await provider.send(message);
    expect(result.ok).toBe(true);
    expect(tokens.deactivateByIds).toHaveBeenCalledWith(['id-a']);
  });

  it('does not retry when every token is unregistered', async () => {
    tokens.listActive.mockResolvedValue([
      { push_device_token_id: 'id-a', fcm_token: tokenA },
    ]);
    (messaging.sendEachForMulticast as jest.Mock).mockResolvedValue({
      successCount: 0,
      failureCount: 1,
      responses: [
        {
          success: false,
          error: { code: 'messaging/invalid-registration-token' },
        },
      ],
    });
    await expect(provider.send(message)).resolves.toEqual({
      ok: false,
      error: 'fcm:all-tokens-unregistered',
      retryable: false,
    });
    expect(tokens.deactivateByIds).toHaveBeenCalledWith(['id-a']);
  });

  it('retries on transient FCM failures', async () => {
    tokens.listActive.mockResolvedValue([
      { push_device_token_id: 'id-a', fcm_token: tokenA },
    ]);
    (messaging.sendEachForMulticast as jest.Mock).mockRejectedValue(
      new Error('UNAVAILABLE'),
    );
    await expect(provider.send(message)).resolves.toEqual({
      ok: false,
      error: 'fcm:unavailable',
      retryable: true,
    });
    const logged = JSON.stringify((logger.error as jest.Mock).mock.calls);
    expect(logged).not.toContain(tokenA);
    expect(logged).not.toContain('BEGIN PRIVATE KEY');
  });

  it('fails permanently when the identity has no device tokens', async () => {
    tokens.listActive.mockResolvedValue([]);
    await expect(provider.send(message)).resolves.toEqual({
      ok: false,
      error: 'fcm:no-device-tokens',
      retryable: false,
    });
    expect(messaging.sendEachForMulticast).not.toHaveBeenCalled();
  });
});
