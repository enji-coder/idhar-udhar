import { createHmac } from 'node:crypto';
import { CashfreePayoutWebhookController } from './cashfree-payout-webhook.controller';
import { CashfreeWebhookController } from './cashfree-webhook.controller';

const PG_SECRET = 'pg_secret_not_real';
const PAYOUT_SECRET = 'payout_secret_not_real';

function sign(secret: string, rawBody: string, timestamp: string): string {
  return createHmac('sha256', secret).update(timestamp + rawBody).digest('base64');
}

function payoutRequest(secret: string) {
  const raw = JSON.stringify({
    type: 'TRANSFER_SUCCESS',
    data: { transfer_id: 'w-transfer-1', status: 'SUCCESS', cf_transfer_id: 'cf-1' },
  });
  const timestamp = String(Date.now());
  return {
    rawBody: Buffer.from(raw),
    headers: {
      'x-webhook-timestamp': timestamp,
      'x-webhook-signature': sign(secret, raw, timestamp),
    },
  };
}

function paymentConfig(payoutSecret: string | null) {
  return {
    getOrThrow: () => ({
      provider: 'cashfree',
      cashfree: {
        environment: 'production',
        clientId: 'pg_client',
        clientSecret: PG_SECRET,
        payoutClientId: payoutSecret ? 'payout_client' : null,
        payoutClientSecret: payoutSecret,
      },
    }),
  };
}

describe('Cashfree payout webhook credentials', () => {
  it('accepts a signature made with the payout secret', async () => {
    const apply = jest.fn(async () => ({ result: 'applied', status: 'SUCCESSFUL' }));
    const controller = new CashfreePayoutWebhookController(
      paymentConfig(PAYOUT_SECRET) as never,
      { applyPayoutWebhookByMerchantTransferId: apply } as never,
    );
    const result = await controller.webhook(payoutRequest(PAYOUT_SECRET) as never);
    expect(result).toMatchObject({ received: true, result: 'applied' });
    expect(apply).toHaveBeenCalledWith(
      expect.objectContaining({ merchantTransferId: 'w-transfer-1' }),
    );
  });

  it('rejects a signature made with the payment gateway secret', async () => {
    const apply = jest.fn();
    const controller = new CashfreePayoutWebhookController(
      paymentConfig(PAYOUT_SECRET) as never,
      { applyPayoutWebhookByMerchantTransferId: apply } as never,
    );
    await expect(controller.webhook(payoutRequest(PG_SECRET) as never)).rejects.toMatchObject({
      code: 'PAYMENT_WEBHOOK_INVALID',
      status: 401,
    });
    expect(apply).not.toHaveBeenCalled();
  });

  it('refuses the payout webhook when the payout secret is missing', async () => {
    const controller = new CashfreePayoutWebhookController(
      paymentConfig(null) as never,
      { applyPayoutWebhookByMerchantTransferId: jest.fn() } as never,
    );
    await expect(controller.webhook(payoutRequest(PAYOUT_SECRET) as never)).rejects.toMatchObject({
      code: 'PAYMENT_PROVIDER_UNAVAILABLE',
      status: 503,
    });
  });
});

describe('Cashfree payment webhook credentials', () => {
  const originalTier = process.env.IU_DEPLOYMENT_TIER;

  function restoreTier(): void {
    if (originalTier === undefined) {
      delete process.env.IU_DEPLOYMENT_TIER;
    } else {
      process.env.IU_DEPLOYMENT_TIER = originalTier;
    }
  }

  afterEach(() => {
    restoreTier();
  });

  function controllerWith(apply: jest.Mock, warn: jest.Mock) {
    return new CashfreeWebhookController(
      paymentConfig(PAYOUT_SECRET) as never,
      { apply } as never,
      { warn } as never,
    );
  }

  it('rejects a signature made with the payout secret', async () => {
    const apply = jest.fn();
    const controller = controllerWith(apply, jest.fn());
    const raw = '{"type":"PAYMENT_SUCCESS_WEBHOOK"}';
    const timestamp = String(Date.now());
    await expect(
      controller.webhook({
        rawBody: Buffer.from(raw),
        headers: {
          'x-webhook-timestamp': timestamp,
          'x-webhook-signature': sign(PAYOUT_SECRET, raw, timestamp),
        },
      } as never),
    ).rejects.toMatchObject({
      code: 'PAYMENT_WEBHOOK_INVALID',
      status: 401,
    });
    expect(apply).not.toHaveBeenCalled();
  });

  it('accepts a signature made with the payment gateway secret', async () => {
    const apply = jest.fn(async () => 'applied');
    const warn = jest.fn();
    const controller = controllerWith(apply, warn);
    const raw = '{"type":"PAYMENT_SUCCESS_WEBHOOK","data":{}}';
    const timestamp = String(Date.now());
    const result = await controller.webhook({
      rawBody: Buffer.from(raw),
      headers: {
        'x-webhook-timestamp': timestamp,
        'x-webhook-signature': sign(PG_SECRET, raw, timestamp),
      },
    } as never);
    expect(result).toEqual({ received: true, result: 'applied' });
    expect(apply).toHaveBeenCalledTimes(1);
    expect(warn).not.toHaveBeenCalled();
  });

  it('logs only the signature reason on staging and still returns 401', async () => {
    process.env.IU_DEPLOYMENT_TIER = 'staging';
    const apply = jest.fn();
    const warn = jest.fn();
    const controller = controllerWith(apply, warn);
    const raw = '{"type":"PAYMENT_SUCCESS_WEBHOOK"}';
    const timestamp = String(Date.now());
    const signature = sign(PAYOUT_SECRET, raw, timestamp);
    await expect(
      controller.webhook({
        rawBody: Buffer.from(raw),
        headers: {
          'x-webhook-timestamp': timestamp,
          'x-webhook-signature': signature,
        },
      } as never),
    ).rejects.toMatchObject({
      code: 'PAYMENT_WEBHOOK_INVALID',
      status: 401,
    });
    expect(apply).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith('cashfree_webhook_rejected', {
      reason: 'signature',
    });
    const logged = JSON.stringify(warn.mock.calls);
    expect(logged).not.toContain(signature);
    expect(logged).not.toContain(timestamp);
    expect(logged).not.toContain(raw);
    expect(logged).not.toContain(PG_SECRET);
    expect(logged).not.toContain(PAYOUT_SECRET);
  });

  it('logs only the timestamp reason when the signature is valid but stale', async () => {
    process.env.IU_DEPLOYMENT_TIER = 'staging';
    const warn = jest.fn();
    const controller = controllerWith(jest.fn(), warn);
    const raw = '{"type":"PAYMENT_FAILED_WEBHOOK"}';
    const timestamp = String(Date.now() - 73 * 60 * 60 * 1000);
    const signature = sign(PG_SECRET, raw, timestamp);
    await expect(
      controller.webhook({
        rawBody: Buffer.from(raw),
        headers: {
          'x-webhook-timestamp': timestamp,
          'x-webhook-signature': signature,
        },
      } as never),
    ).rejects.toMatchObject({ status: 401, code: 'PAYMENT_WEBHOOK_INVALID' });
    expect(warn).toHaveBeenCalledWith('cashfree_webhook_rejected', {
      reason: 'timestamp',
    });
    const logged = JSON.stringify(warn.mock.calls);
    expect(logged).not.toContain(timestamp);
    expect(logged).not.toContain(signature);
    expect(logged).not.toContain(raw);
    expect(logged).not.toContain(PG_SECRET);
  });

  it('does not log the rejection reason outside staging', async () => {
    process.env.IU_DEPLOYMENT_TIER = 'production';
    const warn = jest.fn();
    const controller = controllerWith(jest.fn(), warn);
    const raw = '{"type":"PAYMENT_SUCCESS_WEBHOOK"}';
    const timestamp = String(Date.now());
    await expect(
      controller.webhook({
        rawBody: Buffer.from(raw),
        headers: {
          'x-webhook-timestamp': timestamp,
          'x-webhook-signature': sign(PAYOUT_SECRET, raw, timestamp),
        },
      } as never),
    ).rejects.toMatchObject({ status: 401 });
    expect(warn).not.toHaveBeenCalled();
  });
});
