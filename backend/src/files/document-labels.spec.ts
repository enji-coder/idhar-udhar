import { riderDocumentLabel } from './document-labels';

describe('riderDocumentLabel', () => {
  it('maps known rider document types to readable names', () => {
    expect(riderDocumentLabel('DRIVING_LICENSE_FRONT')).toBe(
      'Driving Licence (front)',
    );
    expect(riderDocumentLabel('BANK_PROOF')).toBe('Bank verification');
  });
});
