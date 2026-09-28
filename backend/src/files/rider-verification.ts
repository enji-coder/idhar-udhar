import { RIDER_DOCUMENT_TYPES } from './file-validation';

export const VERIFICATION_SOURCES = ['ADMIN', 'IDFY'] as const;

export type VerificationSource = (typeof VERIFICATION_SOURCES)[number];

export type DocumentDecisionStatus = 'UPLOADED' | 'APPROVED' | 'REJECTED';

export type VerificationDocument = {
  document_type: string;
  status: DocumentDecisionStatus;
  created_at: Date;
  reviewed_at?: Date | null;
};

export type DerivedVerification = {
  approval_status: 'PENDING' | 'APPROVED' | 'REJECTED';
  onboarding_kyc_status: 'PENDING' | 'SUBMITTED' | 'APPROVED' | 'REJECTED';
};

export function isVerificationSource(value: string): value is VerificationSource {
  return (VERIFICATION_SOURCES as readonly string[]).includes(value);
}

/** Newest row per document type is the one that counts. Older decisions stay stored. */
export function latestDocuments<T extends VerificationDocument>(rows: readonly T[]): T[] {
  const byType = new Map<string, T>();
  for (const row of rows) {
    const current = byType.get(row.document_type);
    if (!current || row.created_at.getTime() >= current.created_at.getTime()) {
      byType.set(row.document_type, row);
    }
  }
  return [...byType.values()];
}

/**
 * All mandatory types are the existing rider document catalog.
 * Missing, uploaded, or rejected types keep the rider unverified.
 */
export function documentsAreLocked(approvalStatus: string): boolean {
  return approvalStatus === 'APPROVED';
}

function effectiveStatus(
  row: VerificationDocument,
  reopenedAt: Date | null | undefined,
): DocumentDecisionStatus | null {
  if (row.status === 'UPLOADED') {
    return 'UPLOADED';
  }
  if (
    reopenedAt &&
    (!row.reviewed_at || row.reviewed_at.getTime() <= reopenedAt.getTime())
  ) {
    return null;
  }
  return row.status;
}

export function deriveVerification(
  rows: readonly VerificationDocument[],
  reopenedAt?: Date | null,
): DerivedVerification {
  const latest = latestDocuments(rows);
  const byType = new Map(
    latest.map((row) => [row.document_type, effectiveStatus(row, reopenedAt)]),
  );
  const statuses = RIDER_DOCUMENT_TYPES.map((type) => byType.get(type) ?? null);
  if (statuses.every((status) => status === 'APPROVED')) {
    return { approval_status: 'APPROVED', onboarding_kyc_status: 'APPROVED' };
  }
  if (statuses.some((status) => status === 'REJECTED')) {
    return { approval_status: 'REJECTED', onboarding_kyc_status: 'REJECTED' };
  }
  if (statuses.some((status) => status != null) || rows.length > 0) {
    return { approval_status: 'PENDING', onboarding_kyc_status: 'SUBMITTED' };
  }
  return { approval_status: 'PENDING', onboarding_kyc_status: 'PENDING' };
}

export function riderMayGoOnline(approvalStatus: string): boolean {
  return approvalStatus === 'APPROVED';
}

export function riderMayAccessRides(input: {
  approvalStatus: string;
  deactivated: boolean;
}): boolean {
  return !input.deactivated && input.approvalStatus === 'APPROVED';
}
