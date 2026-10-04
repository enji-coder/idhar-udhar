import { renderNotification } from './templates';

describe('notification templates', () => {
  it('keeps customer assignment copy structured', () => {
    const rendered = renderNotification('ORDER_RIDER_ASSIGNED', 'CUSTOMER', {
      displayId: 'IU-AMD-0000000001',
    });
    expect(rendered.title).toBe('Rider assigned');
    expect(rendered.body).toContain('IU-AMD-0000000001');
  });

  it('uses a distinct rider offer title', () => {
    const rendered = renderNotification('OFFER_NEW', 'RIDER', {
      displayId: 'IU-AMD-0000000001',
    });
    expect(rendered.title).toBe('New delivery request');
  });

  it('names approved and rejected rider documents clearly', () => {
    const approved = renderNotification('RIDER_DOCUMENT_APPROVED', 'RIDER', {
      documentName: 'Driving Licence (front)',
    });
    expect(approved.body).toBe('Your Driving Licence (front) has been approved.');

    const rejected = renderNotification('RIDER_DOCUMENT_REJECTED', 'RIDER', {
      documentName: 'Driving Licence',
      reason: 'Photo is blurry',
    });
    expect(rejected.body).toContain('Your Driving Licence was rejected');
    expect(rejected.body).toContain('Reason: Photo is blurry');
  });

  it('does not put secrets or raw phones in bodies', () => {
    const types = [
      'ORDER_CONFIRMED',
      'PAYMENT_SUCCESSFUL',
      'WALLET_RECHARGE_COMPLETED',
      'WITHDRAWAL_REQUESTED',
      'COD_SUSPENDED',
    ] as const;
    for (const type of types) {
      const rendered = renderNotification(type, 'CUSTOMER', {
        displayId: 'IU-AMD-0000000001',
        amount: '100.00',
      });
      expect(rendered.body).not.toMatch(/\+91/);
      expect(rendered.body).not.toMatch(/token/i);
    }
  });
});
