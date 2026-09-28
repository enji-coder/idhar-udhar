import { createHash, randomUUID } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext } from '../auth/types/auth-context';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { AuditService } from '../audit/audit.service';
import { NotificationService } from '../notifications/notification.service';
import { OBJECT_STORAGE, ObjectStorage } from '../storage/object-storage';
import {
  isRiderDocumentType,
  UploadedBinary,
  validateProfileImage,
  validateUpload,
} from './file-validation';
import { FilesRepository, RiderDocumentRow } from './files.repository';
import {
  fileNameFromStorageKey,
  riderDocumentObjectKey,
  riderProfilePictureObjectKey,
} from './object-key';
import {
  deriveVerification,
  documentsAreLocked,
  VerificationSource,
} from './rider-verification';

@Injectable()
export class RiderDocumentsService {
  private readonly logger = new Logger(RiderDocumentsService.name);

  constructor(
    private readonly postgres: PostgresService,
    private readonly files: FilesRepository,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    private readonly notifications: NotificationService,
    private readonly audit: AuditService,
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
    const rider = await this.files.findRiderVerification(riderProfileId);
    return {
      documents: rows.map((row) => this.serializeDocument(row)),
      approval_status: rider?.approval_status ?? null,
      onboarding_kyc_status: rider?.onboarding_kyc_status ?? null,
      online_status: rider?.online_status ?? null,
      documents_locked: documentsAreLocked(rider?.approval_status ?? ''),
      preferred_language: rider?.preferred_language ?? null,
      has_profile_picture: Boolean(rider?.profile_picture_file_id),
    };
  }

  async uploadOwn(
    auth: AuthContext,
    documentType: string,
    file: UploadedBinary | undefined,
  ) {
    this.assertRider(auth);
    const gate = await this.files.findRiderVerification(auth.profileId);
    if (gate && documentsAreLocked(gate.approval_status)) {
      throw new ApiError(
        ErrorCodes.RIDER_DOCUMENTS_LOCKED,
        'Verified documents are locked',
        409,
      );
    }
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
        const saved = await this.files.insertRiderDocument(
          {
            documentId,
            riderProfileId: auth.profileId,
            documentType,
            fileId,
          },
          tx,
        );
        await this.syncVerification(auth.profileId, tx);
        return saved;
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

  async decideForAdmin(
    auth: AuthContext,
    documentId: string,
    decision: 'APPROVED' | 'REJECTED',
    rejectionReason?: string,
  ) {
    this.assertAdmin(auth);
    return this.decideDocument({
      documentId,
      decision,
      source: 'ADMIN',
      adminProfileId: auth.profileId,
      rejectionReason,
    });
  }

  /**
   * Shared decision path. Admin review calls this with source ADMIN.
   * A future IDfy caller uses source IDFY and a null reviewer. There is no IDfy HTTP route.
   */
  async decideDocument(input: {
    documentId: string;
    decision: 'APPROVED' | 'REJECTED';
    source: VerificationSource;
    adminProfileId: string | null;
    rejectionReason?: string | null;
  }) {
    if (input.source === 'ADMIN' && !input.adminProfileId) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Admin reviewer is required',
        400,
      );
    }
    if (input.source === 'IDFY' && input.adminProfileId) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'IDfy decisions do not use an admin reviewer',
        400,
      );
    }
    const reason = input.rejectionReason?.trim() ?? '';
    if (input.decision === 'REJECTED' && reason.length === 0) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Rejection reason is required',
        400,
      );
    }
    if (reason.length > 500) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Rejection reason is too long',
        400,
      );
    }

    const outcome = await this.postgres.transaction(async (tx) => {
      const existing = await this.files.findRiderDocument(input.documentId, tx);
      if (!existing) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Document was not found', 404);
      }
      const updated = await this.files.recordDocumentDecision(
        {
          documentId: input.documentId,
          status: input.decision,
          source: input.source,
          adminProfileId: input.source === 'ADMIN' ? input.adminProfileId : null,
          rejectionReason: input.decision === 'REJECTED' ? reason : null,
        },
        tx,
      );
      const sync = await this.syncVerification(existing.rider_profile_id, tx);
      return {
        document: updated,
        previousStatus: existing.status,
        ...sync,
      };
    });

    await this.emitVerificationNotifications(outcome);
    return {
      document: this.serializeDocument(outcome.document),
      approval_status: outcome.approval_status,
      onboarding_kyc_status: outcome.onboarding_kyc_status,
      online_status: outcome.online_status,
    };
  }

  async reopenForAdmin(auth: AuthContext, riderProfileId: string) {
    this.assertAdmin(auth);
    const outcome = await this.postgres.transaction(async (tx) => {
      const locked = await this.files.lockRiderProfile(riderProfileId, tx);
      if (!locked) {
        throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
      }
      if (locked.approval_status === 'SUSPENDED') {
        throw new ApiError(
          ErrorCodes.RIDER_NOT_ELIGIBLE,
          'A suspended rider stays suspended',
          409,
        );
      }
      if (!documentsAreLocked(locked.approval_status)) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Only an approved rider can be reopened for verification',
          409,
        );
      }
      const updated = await this.files.reopenRiderVerification(riderProfileId, tx);
      if (!updated) {
        throw new ApiError(
          ErrorCodes.VALIDATION_ERROR,
          'Only an approved rider can be reopened for verification',
          409,
        );
      }
      await this.audit.record(
        {
          auth,
          action: 'RIDER_VERIFICATION_REOPENED',
          entityType: 'RIDER_PROFILE',
          entityId: riderProfileId,
          category: 'ADMIN',
          oldValue: {
            approval_status: locked.approval_status,
            onboarding_kyc_status: locked.onboarding_kyc_status,
            online_status: locked.online_status,
          },
          newValue: {
            approval_status: updated.approval_status,
            onboarding_kyc_status: updated.onboarding_kyc_status,
            online_status: updated.online_status,
            verification_reopened_at: updated.verification_reopened_at,
          },
        },
        tx,
      );
      return updated;
    });
    return {
      approval_status: outcome.approval_status,
      onboarding_kyc_status: outcome.onboarding_kyc_status,
      online_status: outcome.online_status,
      documents_locked: documentsAreLocked(outcome.approval_status),
    };
  }

  async uploadProfilePicture(auth: AuthContext, file: UploadedBinary | undefined) {
    this.assertRider(auth);
    const validated = validateProfileImage(file);
    const fileId = randomUUID();
    const storageKey = riderProfilePictureObjectKey({
      riderProfileId: auth.profileId,
      fileId,
      fileName: validated.safeFileName,
    });
    const checksum = createHash('sha256').update(validated.buffer).digest('hex');
    await this.storage.putObject({
      key: storageKey,
      body: validated.buffer,
      contentType: validated.contentType,
    });
    try {
      const replaced = await this.postgres.transaction(async (tx) => {
        const locked = await this.files.lockRiderProfile(auth.profileId, tx);
        if (!locked) {
          throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
        }
        await this.files.insertStoredFile(
          {
            fileId,
            storageKey,
            contentType: validated.contentType,
            sizeBytes: validated.sizeBytes,
            checksum,
            purpose: 'OTHER',
            createdByIdentityId: auth.identityId,
          },
          tx,
        );
        const previous = await this.files.findProfilePicture(auth.profileId, tx);
        await this.files.setProfilePicture(auth.profileId, fileId, tx);
        if (previous) {
          await this.files.deleteStoredFile(previous.file_id, tx);
        }
        return {
          approval_status: locked.approval_status,
          online_status: locked.online_status,
          previousKey: previous?.storage_key ?? null,
        };
      });
      if (replaced.previousKey) {
        try {
          await this.storage.deleteObject(replaced.previousKey);
        } catch (err) {
          this.logger.error(
            `Previous profile picture cleanup failed for rider ${auth.profileId} key ${replaced.previousKey}`,
            err instanceof Error ? err.stack : undefined,
          );
        }
      }
      const signed = await this.storage.getSignedGetUrl(
        storageKey,
        fileNameFromStorageKey(storageKey),
      );
      return {
        profile_picture_file_id: fileId,
        download_url: signed.url,
        download_url_expires_in: signed.expiresInSeconds,
        approval_status: replaced.approval_status,
        online_status: replaced.online_status,
      };
    } catch (err) {
      await this.storage.deleteObject(storageKey).catch(() => undefined);
      throw err;
    }
  }

  async viewOwnProfilePicture(auth: AuthContext) {
    this.assertRider(auth);
    return this.signedProfilePicture(auth.profileId);
  }

  async viewProfilePictureForAdmin(auth: AuthContext, riderProfileId: string) {
    this.assertAdmin(auth);
    if (!(await this.files.riderExists(riderProfileId))) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
    }
    return this.signedProfilePicture(riderProfileId);
  }

  async downloadForAdmin(auth: AuthContext, documentId: string) {
    this.assertAdmin(auth);
    const row = await this.requireDocument(documentId);
    return this.signedDocument(row);
  }

  private async signedProfilePicture(riderProfileId: string) {
    const picture = await this.files.findProfilePicture(riderProfileId);
    if (!picture) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Profile picture was not found', 404);
    }
    const signed = await this.storage.getSignedGetUrl(
      picture.storage_key,
      fileNameFromStorageKey(picture.storage_key),
    );
    return {
      profile_picture_file_id: picture.file_id,
      download_url: signed.url,
      download_url_expires_in: signed.expiresInSeconds,
    };
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
      reviewed_at: row.reviewed_at ? row.reviewed_at.toISOString() : null,
      reviewer_admin_profile_id: row.reviewer_admin_profile_id,
      rejection_reason: row.rejection_reason,
      verification_source: row.verification_source,
    };
  }

  private async syncVerification(riderProfileId: string, db: Queryable) {
    const locked = await this.files.lockRiderProfile(riderProfileId, db);
    if (!locked) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Rider was not found', 404);
    }
    const rows = await this.files.listRiderDocuments(riderProfileId, db);
    if (rows.length === 0) {
      return {
        previousApproval: locked.approval_status,
        approval_status: locked.approval_status,
        onboarding_kyc_status: locked.onboarding_kyc_status,
        online_status: locked.online_status,
      };
    }
    const derived = deriveVerification(rows, locked.verification_reopened_at);
    const approvalStatus =
      locked.approval_status === 'SUSPENDED' ? 'SUSPENDED' : derived.approval_status;
    const onlineStatus = approvalStatus === 'APPROVED' ? locked.online_status : 'OFFLINE';
    if (
      approvalStatus !== locked.approval_status ||
      derived.onboarding_kyc_status !== locked.onboarding_kyc_status ||
      onlineStatus !== locked.online_status
    ) {
      await this.files.updateRiderVerification(
        {
          riderProfileId,
          approvalStatus,
          onboardingKycStatus: derived.onboarding_kyc_status,
          onlineStatus,
        },
        db,
      );
    }
    return {
      previousApproval: locked.approval_status,
      approval_status: approvalStatus,
      onboarding_kyc_status: derived.onboarding_kyc_status,
      online_status: onlineStatus,
    };
  }

  private async emitVerificationNotifications(outcome: {
    document: RiderDocumentRow;
    previousStatus: RiderDocumentRow['status'];
    previousApproval: string;
    approval_status: string;
  }) {
    const becameVerified =
      outcome.previousApproval !== 'APPROVED' && outcome.approval_status === 'APPROVED';
    const rejectedNow =
      outcome.previousStatus !== 'REJECTED' && outcome.document.status === 'REJECTED';
    if (!becameVerified && !rejectedNow) {
      return;
    }
    const reviewedAt = outcome.document.reviewed_at?.toISOString() ?? outcome.document.rider_document_id;
    try {
      if (becameVerified) {
        await this.notifications.notifyIfRecipient(
          {
            eventKey: `verification:${outcome.document.rider_document_id}:APPROVED:${reviewedAt}`,
            type: 'RIDER_PROFILE_VERIFIED',
            audience: 'RIDER',
            profileType: 'RIDER',
            profileId: outcome.document.rider_profile_id,
          },
          this.postgres,
        );
      }
      if (rejectedNow) {
        await this.notifications.notifyIfRecipient(
          {
            eventKey: `verification:${outcome.document.rider_document_id}:REJECTED:${reviewedAt}`,
            type: 'RIDER_DOCUMENT_REJECTED',
            audience: 'RIDER',
            profileType: 'RIDER',
            profileId: outcome.document.rider_profile_id,
            reason: outcome.document.rejection_reason,
          },
          this.postgres,
        );
      }
    } catch (err) {
      this.logger.error(
        `Verification notification failed for rider ${outcome.document.rider_profile_id}`,
        err instanceof Error ? err.stack : undefined,
      );
    }
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
