import { UnconfiguredPaymentProvider } from './unconfigured-payment.provider';

describe('UnconfiguredPaymentProvider', () => {
  it('records an intent only and never pretends a gateway captured funds', () => {
    const provider = new UnconfiguredPaymentProvider();
    const result = provider.beginOnlineCharge({
      orderId: '11111111-1111-1111-1111-111111111111',
      amount: '100.00',
      payerType: 'CUSTOMER',
    });
    expect(result.providerTxnId).toBeNull();
    expect(result.providerEventId).toBeNull();
  });
});
