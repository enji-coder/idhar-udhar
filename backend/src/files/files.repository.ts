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
  created_at: Date;
  storage_key: string;
  content_type: string | null;
  size_bytes: number | null;
  purpose: StoredFilePurpose;
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
        reviewer_admin_profile_id, reviewed_at, created_at
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
