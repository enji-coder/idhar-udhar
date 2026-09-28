import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  canSubmitReview,
  documentsLockedLabel,
  documentLabel,
  languageLabel,
  documentStatusLabel,
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
});
