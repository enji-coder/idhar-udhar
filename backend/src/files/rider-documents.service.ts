import { createHash, randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { PostgresService } from '../database/postgres.service';
import { OBJECT_STORAGE, ObjectStorage } from '../storage/object-storage';
import {
  isRiderDocumentType,
  UploadedBinary,
  validateUpload,
} from './file-validation';
import { FilesRepository, RiderDocumentRow } from './files.repository';
import { fileNameFromStorageKey, riderDocumentObjectKey } from './object-key';

@Injectable()
export class RiderDocumentsService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly files: FilesRepository,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
  ) {}

  async listOwn(auth: AuthContext) {
    this.assertRider(auth);
    const rows = await this.files.listRiderDocuments(auth.profileId);
    return { documents: rows.map((row) => this.serializeDocument(row)) };
  }

  async listForAdmin(auth: AuthContext, riderProfileId: string) {
    this.assertAdmin(auth);
    if (!(await this.files.riderExists(riderProfileId))) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
    }
    const rows = await this.files.listRiderDocuments(riderProfileId);
    return { documents: rows.map((row) => this.serializeDocument(row)) };
  }

  async uploadOwn(
    auth: AuthContext,
    documentType: string,
    file: UploadedBinary | undefined,
  ) {
    this.assertRider(auth);
    if (!isRiderDocumentType(documentType)) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'document_type is not allowed',
        400,
      );
    }
    const validated = validateUpload(file);
    const documentId = randomUUID();
    const fileId = randomUUID();
    const storageKey = riderDocumentObjectKey({
      riderProfileId: auth.profileId,
      documentId,
      fileName: validated.safeFileName,
    });
    const checksum = createHash('sha256').update(validated.buffer).digest('hex');

    await this.storage.putObject({
      key: storageKey,
      body: validated.buffer,
      contentType: validated.contentType,
    });

    try {
      const saved = await this.postgres.transaction(async (tx) => {
        await this.files.insertStoredFile(
          {
            fileId,
            storageKey,
            contentType: validated.contentType,
            sizeBytes: validated.sizeBytes,
            checksum,
            purpose: 'KYC',
            createdByIdentityId: auth.identityId,
          },
          tx,
        );
        return this.files.insertRiderDocument(
          {
            documentId,
            riderProfileId: auth.profileId,
            documentType,
            fileId,
          },
          tx,
        );
      });
      return this.serializeDocument({
        ...saved,
        storage_key: storageKey,
        content_type: validated.contentType,
        size_bytes: validated.sizeBytes,
        purpose: 'KYC',
      });
    } catch (err) {
      await this.storage.deleteObject(storageKey).catch(() => undefined);
      throw err;
    }
  }

  async downloadOwn(auth: AuthContext, documentId: string) {
    this.assertRider(auth);
    const row = await this.requireDocument(documentId);
    if (row.rider_profile_id !== auth.profileId) {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        'Rider cannot access another rider document',
        403,
      );
    }
    return this.signedDocument(row);
  }

  async downloadForAdmin(auth: AuthContext, documentId: string) {
    this.assertAdmin(auth);
    const row = await this.requireDocument(documentId);
    return this.signedDocument(row);
  }

  private async signedDocument(row: RiderDocumentRow) {
    const signed = await this.storage.getSignedGetUrl(
      row.storage_key,
      fileNameFromStorageKey(row.storage_key),
    );
    return {
      ...this.serializeDocument(row),
      download_url: signed.url,
      download_url_expires_in: signed.expiresInSeconds,
    };
  }

  private async requireDocument(documentId: string): Promise<RiderDocumentRow> {
    const row = await this.files.findRiderDocument(documentId);
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Document was not found', 404);
    }
    return row;
  }

  private serializeDocument(row: RiderDocumentRow) {
    return {
      rider_document_id: row.rider_document_id,
      rider_profile_id: row.rider_profile_id,
      document_type: row.document_type,
      status: row.status,
      file_id: row.file_id,
      content_type: row.content_type,
      size_bytes: row.size_bytes,
      created_at: row.created_at.toISOString(),
    };
  }

  private assertRider(auth: AuthContext): void {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider role required', 403);
    }
  }

  private assertAdmin(auth: AuthContext): void {
    if (auth.role !== 'ADMIN') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Admin role required', 403);
    }
  }
}
