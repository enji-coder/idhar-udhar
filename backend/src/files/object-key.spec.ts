import {
  orderPodObjectKey,
  riderDocumentObjectKey,
  safeFileName,
} from './object-key';

const riderId = '11111111-1111-4111-8111-111111111111';
const documentId = '22222222-2222-4222-8222-222222222222';
const orderId = '33333333-3333-4333-8333-333333333333';
const stopId = '44444444-4444-4444-8444-444444444444';

describe('object-key', () => {
  it('builds a rider document key that cannot traverse directories', () => {
    const key = riderDocumentObjectKey({
      riderProfileId: riderId,
      documentId,
      fileName: '../../etc/passwd.jpg',
    });
    expect(key).toBe(`riders/${riderId}/documents/${documentId}/passwd.jpg`);
    expect(key.includes('..')).toBe(false);
  });

  it('builds a POD key from order and stop ids only', () => {
    const key = orderPodObjectKey({
      orderId,
      stopId,
      fileName: 'drop\\photo.png',
    });
    expect(key).toBe(`orders/${orderId}/pod/${stopId}/photo.png`);
  });

  it('rejects user-controlled ids in the key path', () => {
    expect(() =>
      riderDocumentObjectKey({
        riderProfileId: '../not-a-uuid',
        documentId,
        fileName: 'a.jpg',
      }),
    ).toThrow(/Unsafe riderProfileId/);
  });

  it('sanitizes unsafe filenames', () => {
    expect(safeFileName('a b$.PNG', 'image/png')).toBe('a_b_.png');
    expect(safeFileName('', 'image/jpeg')).toBe('file.jpg');
  });
});
