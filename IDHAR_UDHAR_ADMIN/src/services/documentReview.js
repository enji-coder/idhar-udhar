export const DOCUMENT_LABELS = {
  AADHAAR_FRONT: 'Aadhaar Front',
  AADHAAR_BACK: 'Aadhaar Back',
  PAN_FRONT: 'PAN Card',
  DRIVING_LICENSE_FRONT: 'DL Front',
  DRIVING_LICENSE_BACK: 'DL Back',
  VEHICLE_RC_FRONT: 'RC Front',
  VEHICLE_RC_BACK: 'RC Back',
  BANK_PROOF: 'Bank Proof',
};

export function documentLabel(documentType) {
  return DOCUMENT_LABELS[documentType] || documentType || 'Document';
}

export function documentStatusLabel(status) {
  if (status === 'APPROVED') return 'Verified';
  if (status === 'REJECTED') return 'Rejected';
  return 'Pending';
}

export function verificationSourceLabel(source) {
  if (source === 'ADMIN') return 'Admin';
  if (source === 'IDFY') return 'IDfy';
  return 'Not reviewed';
}

export function rejectionIssue(reason) {
  const trimmed = String(reason ?? '').trim();
  if (!trimmed) return 'A rejection reason is required.';
  if (trimmed.length > 500) return 'Rejection reason must be 500 characters or fewer.';
  return '';
}

export function canSubmitReview(submitting) {
  return !submitting;
}

export function languageLabel(code) {
  if (code === 'en') return 'English';
  if (code === 'hi') return 'Hindi';
  if (code === 'gu') return 'Gujarati';
  return code ? String(code) : 'Not set';
}

export function documentsLockedLabel(locked) {
  return locked ? 'Locked' : 'Unlocked';
}
