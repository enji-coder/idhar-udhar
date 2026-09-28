import { RIDER_DOCUMENT_TYPES } from './file-validation';
import {
  deriveVerification,
  documentsAreLocked,
  latestDocuments,
  riderMayAccessRides,
  riderMayGoOnline,
  VerificationDocument,
} from './rider-verification';

function row(
  documentType: string,
  status: VerificationDocument['status'],
  createdAt: string,
): VerificationDocument {
  return {
    document_type: documentType,
    status,
    created_at: new Date(createdAt),
  };
}

describe('rider verification decisions', () => {
  it('verifies only when every mandatory document is approved', () => {
    const docs = RIDER_DOCUMENT_TYPES.map((type) =>
      row(type, 'APPROVED', '2026-09-20T00:00:00.000Z'),
    );
    expect(deriveVerification(docs)).toEqual({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
    });
  });

  it('keeps the rider pending while any mandatory document is missing or uploaded', () => {
    const docs = RIDER_DOCUMENT_TYPES.slice(0, -1).map((type) =>
      row(type, 'APPROVED', '2026-09-20T00:00:00.000Z'),
    );
    expect(deriveVerification(docs).approval_status).toBe('PENDING');
    docs.push(row('BANK_PROOF', 'UPLOADED', '2026-09-21T00:00:00.000Z'));
    expect(deriveVerification(docs)).toEqual({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
    });
  });

  it('rejects the rider when the latest row of any type is rejected', () => {
    const docs = RIDER_DOCUMENT_TYPES.map((type) =>
      row(type, type === 'PAN_FRONT' ? 'REJECTED' : 'APPROVED', '2026-09-20T00:00:00.000Z'),
    );
    expect(deriveVerification(docs)).toEqual({
      approval_status: 'REJECTED',
      onboarding_kyc_status: 'REJECTED',
    });
  });

  it('uses the newest upload and ignores an older approval', () => {
    const docs = [
      row('AADHAAR_FRONT', 'APPROVED', '2026-09-19T00:00:00.000Z'),
      row('AADHAAR_FRONT', 'UPLOADED', '2026-09-22T00:00:00.000Z'),
    ];
    expect(latestDocuments(docs)).toEqual([docs[1]]);
    expect(deriveVerification(docs).approval_status).toBe('PENDING');
  });

  it('does not treat an empty document list as verified', () => {
    expect(deriveVerification([])).toEqual({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'PENDING',
    });
  });

  it('ignores document decisions made before an admin reopen', () => {
    const reopenedAt = new Date('2026-09-25T00:00:00.000Z');
    const docs = RIDER_DOCUMENT_TYPES.map((type) => ({
      ...row(type, 'APPROVED', '2026-09-20T00:00:00.000Z'),
      reviewed_at: new Date('2026-09-20T00:00:00.000Z'),
    }));
    expect(deriveVerification(docs, reopenedAt)).toEqual({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
    });
    const reviewedAgain = docs.map((doc) => ({
      ...doc,
      reviewed_at: new Date('2026-09-26T00:00:00.000Z'),
    }));
    expect(deriveVerification(reviewedAgain, reopenedAt).approval_status).toBe('APPROVED');
  });

  it('locks documents only while the rider approval is APPROVED', () => {
    expect(documentsAreLocked('APPROVED')).toBe(true);
    expect(documentsAreLocked('PENDING')).toBe(false);
    expect(documentsAreLocked('REJECTED')).toBe(false);
    expect(documentsAreLocked('SUSPENDED')).toBe(false);
  });

  it('allows ride access and going online only for an approved active rider', () => {
    expect(riderMayGoOnline('APPROVED')).toBe(true);
    expect(riderMayGoOnline('PENDING')).toBe(false);
    expect(riderMayGoOnline('REJECTED')).toBe(false);
    expect(riderMayGoOnline('SUSPENDED')).toBe(false);
    expect(
      riderMayAccessRides({ approvalStatus: 'APPROVED', deactivated: false }),
    ).toBe(true);
    expect(
      riderMayAccessRides({ approvalStatus: 'APPROVED', deactivated: true }),
    ).toBe(false);
    expect(
      riderMayAccessRides({ approvalStatus: 'PENDING', deactivated: false }),
    ).toBe(false);
  });
});
