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

export function adminRiderDocumentsPath(riderId) {
  return `/v1/admin/riders/${encodeURIComponent(riderId)}/documents`;
}

export function adminDocumentPath(documentId, disposition = 'inline') {
  const mode = disposition === 'attachment' ? 'attachment' : 'inline';
  return `/v1/admin/documents/${encodeURIComponent(documentId)}?disposition=${mode}`;
}

export function adminApproveDocumentPath(documentId) {
  return `/v1/admin/documents/${encodeURIComponent(documentId)}/approve`;
}

export function adminRejectDocumentPath(documentId) {
  return `/v1/admin/documents/${encodeURIComponent(documentId)}/reject`;
}

export function previewKind(contentType) {
  if (contentType === 'image/jpeg' || contentType === 'image/png') return 'image';
  if (contentType === 'application/pdf') return 'pdf';
  return 'unsupported';
}

export const PREVIEW_UNAVAILABLE = 'Document preview is temporarily unavailable.';

export function previewErrorMessage(error) {
  const status = Number(error?.status);
  const code = error?.code;
  if (code === 'STORAGE_UNAVAILABLE' || status === 503) return PREVIEW_UNAVAILABLE;
  if (status === 404 || code === 'NOT_FOUND') return 'This document was not found.';
  if (status === 401 || code === 'UNAUTHENTICATED' || code === 'SESSION_EXPIRED') return 'Please sign in again.';
  if (status === 403 || code === 'FORBIDDEN') return 'You do not have access to this document.';
  if (status === 400 || code === 'VALIDATION_ERROR') return error?.message || 'The document request was not valid.';
  if (status === 409) return error?.message || 'This document cannot be previewed in its current state.';
  if (!status || code === 'NETWORK_ERROR') return 'Could not load the document preview.';
  return error?.message || 'Could not load the document preview.';
}

export function mediaPreviewError() {
  return 'The document could not be displayed. It may have expired or is missing from storage. Open the preview again.';
}
