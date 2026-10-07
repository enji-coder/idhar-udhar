import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  adminApproveDocumentPath,
  adminDocumentPath,
  adminRejectDocumentPath,
  adminRiderDocumentsPath,
  canSubmitReview,
  documentsLockedLabel,
  documentLabel,
  languageLabel,
  mediaPreviewError,
  documentStatusLabel,
  previewErrorMessage,
  previewKind,
  PREVIEW_UNAVAILABLE,
  rejectionIssue,
  verificationSourceLabel,
} from './documentReview.js';

describe('admin document review', () => {
  it('labels the existing rider document types', () => {
    assert.equal(documentLabel('AADHAAR_FRONT'), 'Aadhaar Front');
    assert.equal(documentLabel('BANK_PROOF'), 'Bank Proof');
  });

  it('maps server document status onto the existing badges', () => {
    assert.equal(documentStatusLabel('UPLOADED'), 'Pending');
    assert.equal(documentStatusLabel('APPROVED'), 'Verified');
    assert.equal(documentStatusLabel('REJECTED'), 'Rejected');
  });

  it('names the verification source without a second rider status', () => {
    assert.equal(verificationSourceLabel('ADMIN'), 'Admin');
    assert.equal(verificationSourceLabel('IDFY'), 'IDfy');
    assert.equal(verificationSourceLabel(null), 'Not reviewed');
  });

  it('requires a rejection reason and blocks a second submit', () => {
    assert.equal(rejectionIssue('  '), 'A rejection reason is required.');
    assert.equal(rejectionIssue('Photo is unreadable'), '');
    assert.equal(rejectionIssue('x'.repeat(501)).includes('500'), true);
    assert.equal(canSubmitReview(false), true);
    assert.equal(canSubmitReview(true), false);
  });

  it('labels language and the derived document lock', () => {
    assert.equal(languageLabel('hi'), 'Hindi');
    assert.equal(languageLabel(null), 'Not set');
    assert.equal(documentsLockedLabel(true), 'Locked');
    assert.equal(documentsLockedLabel(false), 'Unlocked');
  });

  it('builds the admin document list, preview, approve, and reject paths', () => {
    const riderId = '11111111-1111-4111-8111-111111111111';
    const documentId = '22222222-2222-4222-8222-222222222222';
    assert.equal(adminRiderDocumentsPath(riderId), `/v1/admin/riders/${riderId}/documents`);
    assert.equal(adminDocumentPath(documentId), `/v1/admin/documents/${documentId}?disposition=inline`);
    assert.equal(adminDocumentPath(documentId, 'attachment'), `/v1/admin/documents/${documentId}?disposition=attachment`);
    assert.equal(adminApproveDocumentPath(documentId), `/v1/admin/documents/${documentId}/approve`);
    assert.equal(adminRejectDocumentPath(documentId), `/v1/admin/documents/${documentId}/reject`);
  });

  it('chooses an image or pdf preview and keeps storage failures separate', () => {
    assert.equal(previewKind('image/jpeg'), 'image');
    assert.equal(previewKind('image/png'), 'image');
    assert.equal(previewKind('application/pdf'), 'pdf');
    assert.equal(previewKind('application/octet-stream'), 'unsupported');
    assert.equal(previewErrorMessage({ code: 'STORAGE_UNAVAILABLE', status: 503 }), PREVIEW_UNAVAILABLE);
    assert.equal(previewErrorMessage({ status: 404, code: 'NOT_FOUND' }), 'This document was not found.');
    assert.equal(previewErrorMessage({ status: 403, code: 'FORBIDDEN' }), 'You do not have access to this document.');
    assert.equal(previewErrorMessage({ status: 401, code: 'UNAUTHENTICATED' }), 'Please sign in again.');
    assert.equal(previewErrorMessage({ status: 0, code: 'NETWORK_ERROR' }), 'Could not load the document preview.');
    assert.equal(previewErrorMessage({ status: 500, message: 'Something went wrong.' }), 'Something went wrong.');
    assert.match(mediaPreviewError(), /expired or is missing/);
    assert.equal(previewErrorMessage({ code: 'STORAGE_UNAVAILABLE', status: 503 }).includes('not available on the server'), false);
  });

  it('does not keep the hardcoded verification stub on rider detail', () => {
    const page = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../pages/RiderDetail.jsx'), 'utf8');
    assert.equal(page.includes('Document verification is not available on the server yet.'), false);
    assert.equal(page.includes('fetchAdminRiderDocuments'), true);
    assert.equal(page.includes('fetchAdminDocument'), true);
    assert.equal(page.includes("disposition: 'inline'"), true);
    assert.equal(page.includes("disposition: 'attachment'"), true);
    assert.equal(page.includes('approveAdminDocument'), true);
    assert.equal(page.includes('rejectAdminDocument'), true);
    assert.equal(page.includes('rejectionIssue'), true);
    assert.equal(page.includes('Loading document preview'), true);
    assert.equal(page.includes('Document approved successfully.'), true);
    assert.equal(page.includes('Document rejected successfully.'), true);
    assert.equal(page.includes("if (rider?.source === 'api') return serverDocuments"), true);
    assert.equal(page.includes("can('riders', 'approve')"), true);
    assert.equal(page.includes("can('riders', 'reject')"), true);
  });

  it('calls the existing document approval API from the riders list and deletes through the admin rider route', () => {
    const page = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../pages/Riders.jsx'), 'utf8');
    assert.equal(page.includes('Rider approval is not available on the server yet.'), false);
    assert.equal(page.includes('Deleting riders from Admin is not available on the server yet.'), false);
    assert.equal(page.includes('approveAdminDocument'), true);
    assert.equal(page.includes('fetchAdminRiderDocuments'), true);
    assert.equal(page.includes('deleteAdminRider'), true);
    assert.equal(page.includes('Assign Vehicle'), false);
    assert.equal(page.includes('>Edit<'), false);
  });

  it('does not synthesize document rows for API riders', () => {
    const enrichment = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'profileEnrichment.js'), 'utf8');
    const start = enrichment.indexOf('export function riderDocumentsFor');
    const branch = enrichment.slice(start, enrichment.indexOf('const profile = enrichRiderProfile', start));
    assert.match(branch, /if \(rider\.source === 'api'\) \{\s*return \[\];/);
    assert.equal(branch.includes('Driving License'), false);
    assert.equal(branch.includes('N/A'), false);
  });
});
