-- Who recorded a document decision. Ride access still uses rider_profiles.approval_status.
-- Legacy rows keep a null source and a null reason. A recorded decision must name ADMIN or IDFY.
-- IS NOT NULL is required: a comparison with NULL is UNKNOWN, and CHECK accepts UNKNOWN.

ALTER TABLE rider_documents
  ADD COLUMN rejection_reason TEXT NULL,
  ADD COLUMN verification_source TEXT NULL;

ALTER TABLE rider_documents
  ADD CONSTRAINT rider_documents_verification_chk CHECK (
    (
      verification_source IS NULL
      AND rejection_reason IS NULL
    )
    OR (
      verification_source IS NOT NULL
      AND reviewed_at IS NOT NULL
      AND (
        (verification_source = 'ADMIN' AND reviewer_admin_profile_id IS NOT NULL)
        OR (verification_source = 'IDFY' AND reviewer_admin_profile_id IS NULL)
      )
      AND (
        (status = 'APPROVED' AND rejection_reason IS NULL)
        OR (
          status = 'REJECTED'
          AND rejection_reason IS NOT NULL
          AND length(btrim(rejection_reason)) > 0
        )
      )
    )
  );

COMMENT ON COLUMN rider_documents.verification_source IS
  'ADMIN or IDFY. Both write this row and then the same rider_profiles.approval_status. Null means no decision yet.';
COMMENT ON COLUMN rider_documents.rejection_reason IS
  'Required when a decision rejects the document. Empty for an approval.';
