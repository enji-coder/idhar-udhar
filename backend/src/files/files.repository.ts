import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export type StoredFilePurpose = 'KYC' | 'POD' | 'INVOICE_PDF' | 'OTHER';

export type StoredFileRow = {
  file_id: string;
  storage_key: string;
  content_type: string | null;
  size_bytes: number | null;
  checksum: string | null;
  purpose: StoredFilePurpose;
  virus_scan_status: string | null;
  created_by_identity_id: string | null;
  created_at: Date;
};

export type RiderDocumentRow = {
  rider_document_id: string;
  rider_profile_id: string;
  document_type: string;
  file_id: string;
  status: 'UPLOADED' | 'APPROVED' | 'REJECTED';
  reviewer_admin_profile_id: string | null;
  reviewed_at: Date | null;
  rejection_reason: string | null;
  verification_source: 'ADMIN' | 'IDFY' | null;
  created_at: Date;
  storage_key: string;
  content_type: string | null;
  size_bytes: number | null;
  purpose: StoredFilePurpose;
};

export type RiderVerificationState = {
  approval_status: string;
  onboarding_kyc_status: string;
  online_status: string;
  verification_reopened_at: Date | null;
  preferred_language: string | null;
  profile_picture_file_id: string | null;
};

export type PodFileRow = {
  order_id: string;
  order_stop_id: string;
  stop_type: 'PICKUP' | 'DROP';
  proof_file_id: string;
  storage_key: string;
  content_type: string | null;
  size_bytes: number | null;
  purpose: StoredFilePurpose;
};

@Injectable()
export class FilesRepository {
  constructor(private readonly postgres: PostgresService) {}

  async riderExists(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<boolean> {
    const result = await db.query<{ ok: boolean }>(
      `
      SELECT TRUE AS ok
      FROM rider_profiles
      WHERE rider_profile_id = $1
      LIMIT 1
      `,
      [riderProfileId],
    );
    return result.rows.length > 0;
  }

  async insertStoredFile(
    input: {
      fileId: string;
      storageKey: string;
      contentType: string;
      sizeBytes: number;
      checksum: string;
      purpose: StoredFilePurpose;
      createdByIdentityId: string;
    },
    db: Queryable,
  ): Promise<StoredFileRow> {
    const result = await db.query<StoredFileRow>(
      `
      INSERT INTO stored_files (
        file_id, storage_key, content_type, size_bytes, checksum,
        purpose, virus_scan_status, created_by_identity_id
      )
      VALUES ($1, $2, $3, $4, $5, $6, 'SKIPPED', $7)
      RETURNING
        file_id, storage_key, content_type, size_bytes, checksum,
        purpose, virus_scan_status, created_by_identity_id, created_at
      `,
      [
        input.fileId,
        input.storageKey,
        input.contentType,
        input.sizeBytes,
        input.checksum,
        input.purpose,
        input.createdByIdentityId,
      ],
    );
    return result.rows[0];
  }

  async insertRiderDocument(
    input: {
      documentId: string;
      riderProfileId: string;
      documentType: string;
      fileId: string;
    },
    db: Queryable,
  ): Promise<RiderDocumentRow> {
    const result = await db.query<RiderDocumentRow>(
      `
      INSERT INTO rider_documents (
        rider_document_id, rider_profile_id, document_type, file_id, status
      )
      VALUES ($1, $2, $3, $4, 'UPLOADED')
      RETURNING
        rider_document_id, rider_profile_id, document_type, file_id, status,
        reviewer_admin_profile_id, reviewed_at, rejection_reason, verification_source, created_at
      `,
      [
        input.documentId,
        input.riderProfileId,
        input.documentType,
        input.fileId,
      ],
    );
    const row = result.rows[0];
    return {
      ...row,
      storage_key: '',
      content_type: null,
      size_bytes: null,
      purpose: 'KYC',
      rejection_reason: row.rejection_reason ?? null,
      verification_source: row.verification_source ?? null,
    };
  }

  async listRiderDocuments(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<RiderDocumentRow[]> {
    const result = await db.query<RiderDocumentRow>(
      `
      SELECT
        d.rider_document_id,
        d.rider_profile_id,
        d.document_type,
        d.file_id,
        d.status,
        d.reviewer_admin_profile_id,
        d.reviewed_at,
        d.rejection_reason,
        d.verification_source,
        d.created_at,
        f.storage_key,
        f.content_type,
        f.size_bytes,
        f.purpose
      FROM rider_documents d
      JOIN stored_files f ON f.file_id = d.file_id
      WHERE d.rider_profile_id = $1
      ORDER BY d.created_at DESC
      `,
      [riderProfileId],
    );
    return result.rows;
  }

  async findRiderDocument(
    documentId: string,
    db: Queryable = this.postgres,
  ): Promise<RiderDocumentRow | null> {
    const result = await db.query<RiderDocumentRow>(
      `
      SELECT
        d.rider_document_id,
        d.rider_profile_id,
        d.document_type,
        d.file_id,
        d.status,
        d.reviewer_admin_profile_id,
        d.reviewed_at,
        d.rejection_reason,
        d.verification_source,
        d.created_at,
        f.storage_key,
        f.content_type,
        f.size_bytes,
        f.purpose
      FROM rider_documents d
      JOIN stored_files f ON f.file_id = d.file_id
      WHERE d.rider_document_id = $1
      LIMIT 1
      `,
      [documentId],
    );
    return result.rows[0] ?? null;
  }

  async findPodFile(
    orderId: string,
    stopId: string,
    db: Queryable = this.postgres,
  ): Promise<PodFileRow | null> {
    const result = await db.query<PodFileRow>(
      `
      SELECT
        s.order_id,
        s.order_stop_id,
        s.stop_type,
        s.proof_file_id,
        f.storage_key,
        f.content_type,
        f.size_bytes,
        f.purpose
      FROM order_stops s
      JOIN stored_files f ON f.file_id = s.proof_file_id
      WHERE s.order_id = $1 AND s.order_stop_id = $2 AND s.proof_file_id IS NOT NULL
      LIMIT 1
      `,
      [orderId, stopId],
    );
    return result.rows[0] ?? null;
  }

  async findRiderVerification(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<RiderVerificationState | null> {
    const result = await db.query<RiderVerificationState>(
      `
      SELECT
        approval_status,
        onboarding_kyc_status,
        online_status,
        verification_reopened_at,
        preferred_language,
        profile_picture_file_id
      FROM rider_profiles
      WHERE rider_profile_id = $1
      LIMIT 1
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async lockRiderProfile(
    riderProfileId: string,
    db: Queryable,
  ): Promise<RiderVerificationState | null> {
    const result = await db.query<RiderVerificationState>(
      `
      SELECT
        approval_status,
        onboarding_kyc_status,
        online_status,
        verification_reopened_at,
        preferred_language,
        profile_picture_file_id
      FROM rider_profiles
      WHERE rider_profile_id = $1
      FOR UPDATE
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async updateRiderVerification(
    input: {
      riderProfileId: string;
      approvalStatus: string;
      onboardingKycStatus: string;
      onlineStatus: string;
    },
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      UPDATE rider_profiles
      SET
        approval_status = $2,
        onboarding_kyc_status = $3,
        online_status = $4
      WHERE rider_profile_id = $1
      `,
      [
        input.riderProfileId,
        input.approvalStatus,
        input.onboardingKycStatus,
        input.onlineStatus,
      ],
    );
  }

  async reopenRiderVerification(
    riderProfileId: string,
    db: Queryable,
  ): Promise<RiderVerificationState | null> {
    const result = await db.query<RiderVerificationState>(
      `
      UPDATE rider_profiles
      SET
        approval_status = 'PENDING',
        onboarding_kyc_status = 'SUBMITTED',
        online_status = 'OFFLINE',
        verification_reopened_at = now()
      WHERE rider_profile_id = $1
        AND approval_status = 'APPROVED'
      RETURNING
        approval_status,
        onboarding_kyc_status,
        online_status,
        verification_reopened_at,
        preferred_language,
        profile_picture_file_id
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async setProfilePicture(
    riderProfileId: string,
    fileId: string,
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      UPDATE rider_profiles
      SET profile_picture_file_id = $2
      WHERE rider_profile_id = $1
      `,
      [riderProfileId, fileId],
    );
  }

  async findProfilePicture(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<{ file_id: string; storage_key: string; content_type: string | null } | null> {
    const result = await db.query<{
      file_id: string;
      storage_key: string;
      content_type: string | null;
    }>(
      `
      SELECT f.file_id, f.storage_key, f.content_type
      FROM rider_profiles p
      JOIN stored_files f ON f.file_id = p.profile_picture_file_id
      WHERE p.rider_profile_id = $1
      LIMIT 1
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async deleteStoredFile(fileId: string, db: Queryable): Promise<void> {
    await db.query(`DELETE FROM stored_files WHERE file_id = $1`, [fileId]);
  }

  async recordDocumentDecision(
    input: {
      documentId: string;
      status: 'APPROVED' | 'REJECTED';
      source: 'ADMIN' | 'IDFY';
      adminProfileId: string | null;
      rejectionReason: string | null;
    },
    db: Queryable,
  ): Promise<RiderDocumentRow> {
    await db.query(
      `
      UPDATE rider_documents
      SET
        status = $2,
        verification_source = $3,
        reviewer_admin_profile_id = $4,
        rejection_reason = $5,
        reviewed_at = now()
      WHERE rider_document_id = $1
      `,
      [
        input.documentId,
        input.status,
        input.source,
        input.adminProfileId,
        input.rejectionReason,
      ],
    );
    const row = await this.findRiderDocument(input.documentId, db);
    if (!row) {
      throw new Error('Document was not found after the verification decision');
    }
    return row;
  }

  async attachPodFile(
    stopId: string,
    fileId: string,
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      UPDATE order_stops
      SET proof_file_id = $2
      WHERE order_stop_id = $1
      `,
      [stopId, fileId],
    );
  }
}
