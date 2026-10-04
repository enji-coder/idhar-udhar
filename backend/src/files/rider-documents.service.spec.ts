import { Logger } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { AuthContext } from '../auth/types/auth-context';
import { PostgresService } from '../database/postgres.service';
import { ObjectStorage } from '../storage/object-storage';
import { RIDER_DOCUMENT_TYPES } from './file-validation';
import { AuditService } from '../audit/audit.service';
import { NotificationService } from '../notifications/notification.service';
import { FilesRepository, RiderDocumentRow } from './files.repository';
import { RiderDocumentsService } from './rider-documents.service';

const riderId = '11111111-1111-4111-8111-111111111111';
const otherRiderId = '55555555-5555-4555-8555-555555555555';
const documentId = '22222222-2222-4222-8222-222222222222';
const fileId = '66666666-6666-4666-8666-666666666666';
const adminId = '33333333-3333-4333-8333-333333333333';

function jpeg(): Buffer {
  const buffer = Buffer.alloc(32, 0);
  buffer[0] = 0xff;
  buffer[1] = 0xd8;
  buffer[2] = 0xff;
  return buffer;
}

function adminAuth(): AuthContext {
  return {
    identityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    role: 'ADMIN',
    profileId: adminId,
  };
}

function riderAuth(profileId = riderId): AuthContext {
  return {
    identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    role: 'RIDER',
    profileId,
  };
}

function documentRow(
  ownerId = riderId,
): RiderDocumentRow {
  return {
    rider_document_id: documentId,
    rider_profile_id: ownerId,
    document_type: 'AADHAAR_FRONT',
    file_id: fileId,
    status: 'UPLOADED',
    reviewer_admin_profile_id: null,
    reviewed_at: null,
    rejection_reason: null,
    verification_source: null,
    created_at: new Date('2026-09-19T08:00:00.000Z'),
    storage_key: `riders/${ownerId}/documents/${documentId}/aadhaar.jpg`,
    content_type: 'image/jpeg',
    size_bytes: 32,
    purpose: 'KYC',
  };
}

describe('RiderDocumentsService', () => {
  const storage: jest.Mocked<ObjectStorage> = {
    putObject: jest.fn(),
    deleteObject: jest.fn(),
    getSignedGetUrl: jest.fn(),
  };
  const files = {
    insertStoredFile: jest.fn(),
    insertRiderDocument: jest.fn(),
    listRiderDocuments: jest.fn(),
    findRiderDocument: jest.fn(),
    riderExists: jest.fn(),
    lockRiderProfile: jest.fn(),
    updateRiderVerification: jest.fn(),
    recordDocumentDecision: jest.fn(),
    findRiderVerification: jest.fn(),
    reopenRiderVerification: jest.fn(),
    setProfilePicture: jest.fn(),
    findProfilePicture: jest.fn(),
    deleteStoredFile: jest.fn(),
  };
  const notifications = {
    notifyIfRecipient: jest.fn(),
  };
  const audit = {
    record: jest.fn(),
  };
  const postgres = {
    transaction: jest.fn(async (work: (tx: object) => Promise<unknown>) =>
      work({}),
    ),
  };

  const service = new RiderDocumentsService(
    postgres as unknown as PostgresService,
    files as unknown as FilesRepository,
    storage,
    notifications as unknown as NotificationService,
    audit as unknown as AuditService,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'PENDING',
      online_status: 'OFFLINE',
    });
    files.listRiderDocuments.mockResolvedValue([]);
    files.updateRiderVerification.mockResolvedValue(undefined);
    notifications.notifyIfRecipient.mockResolvedValue(null);
    storage.putObject.mockResolvedValue(undefined);
    storage.deleteObject.mockResolvedValue(undefined);
    storage.getSignedGetUrl.mockResolvedValue({
      url: 'https://example.invalid/obj?X-Amz-Signature=secret',
      expiresInSeconds: 300,
    });
    files.insertStoredFile.mockResolvedValue({});
    files.insertRiderDocument.mockImplementation(async (input) => ({
      ...documentRow(),
      rider_document_id: input.documentId,
      file_id: input.fileId,
      storage_key: '',
    }));
  });

  it('uploads after authorization, validates the file, puts S3, then persists metadata', async () => {
    const result = await service.uploadOwn(riderAuth(), 'AADHAAR_FRONT', {
      buffer: jpeg(),
      mimetype: 'image/jpeg',
      originalname: 'aadhaar.jpg',
    });
    expect(storage.putObject).toHaveBeenCalledWith(
      expect.objectContaining({
        contentType: 'image/jpeg',
        key: expect.stringMatching(
          new RegExp(`^riders/${riderId}/documents/[0-9a-f-]+/aadhaar\\.jpg$`),
        ),
      }),
    );
    expect(files.insertStoredFile).toHaveBeenCalledWith(
      expect.objectContaining({
        purpose: 'KYC',
        contentType: 'image/jpeg',
      }),
      {},
    );
    expect(files.insertRiderDocument).toHaveBeenCalledWith(
      expect.objectContaining({
        riderProfileId: riderId,
        documentType: 'AADHAAR_FRONT',
      }),
      {},
    );
    expect(result).not.toHaveProperty('download_url');
    expect(result).not.toHaveProperty('storage_key');
    expect(result.document_type).toBe('AADHAAR_FRONT');
  });

  it('does not persist metadata when S3 PutObject fails', async () => {
    storage.putObject.mockRejectedValue(
      new ApiError('STORAGE_UNAVAILABLE', 'down', 503),
    );
    await expect(
      service.uploadOwn(riderAuth(), 'AADHAAR_FRONT', {
        buffer: jpeg(),
        mimetype: 'image/jpeg',
        originalname: 'aadhaar.jpg',
      }),
    ).rejects.toMatchObject({ code: 'STORAGE_UNAVAILABLE' });
    expect(files.insertStoredFile).not.toHaveBeenCalled();
    expect(files.insertRiderDocument).not.toHaveBeenCalled();
  });

  it('deletes the S3 object when metadata persistence fails', async () => {
    files.insertStoredFile.mockRejectedValue(new Error('db down'));
    await expect(
      service.uploadOwn(riderAuth(), 'AADHAAR_FRONT', {
        buffer: jpeg(),
        mimetype: 'image/jpeg',
        originalname: 'aadhaar.jpg',
      }),
    ).rejects.toThrow(/db down/);
    expect(storage.deleteObject).toHaveBeenCalledTimes(1);
  });

  it('rejects a customer uploading rider documents', async () => {
    await expect(
      service.uploadOwn(
        { ...riderAuth(), role: 'CUSTOMER' },
        'AADHAAR_FRONT',
        { buffer: jpeg(), mimetype: 'image/jpeg', originalname: 'aadhaar.jpg' },
      ),
    ).rejects.toMatchObject({ code: 'FORBIDDEN', status: 403 });
    expect(storage.putObject).not.toHaveBeenCalled();
  });

  it('rejects an unauthorized rider downloading another rider document', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow(otherRiderId));
    await expect(
      service.downloadOwn(riderAuth(), documentId),
    ).rejects.toMatchObject({ code: 'FORBIDDEN', status: 403 });
    expect(storage.getSignedGetUrl).not.toHaveBeenCalled();
  });

  it('returns a private presigned GET for the owning rider', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    const result = await service.downloadOwn(riderAuth(), documentId);
    expect(storage.getSignedGetUrl).toHaveBeenCalledWith(
      `riders/${riderId}/documents/${documentId}/aadhaar.jpg`,
      'aadhaar.jpg',
      { disposition: 'attachment', contentType: 'image/jpeg' },
    );
    expect(result.download_url_expires_in).toBe(300);
    expect(result.download_url).toContain('X-Amz-Signature');
  });

  function catalog(status: RiderDocumentRow['status'], createdAt = '2026-09-20T08:00:00.000Z') {
    return RIDER_DOCUMENT_TYPES.map((type) => ({
      ...documentRow(),
      rider_document_id: `${type}-row`,
      document_type: type,
      status,
      created_at: new Date(createdAt),
      verification_source: status === 'UPLOADED' ? null : 'ADMIN',
      reviewer_admin_profile_id: status === 'UPLOADED' ? null : adminId,
      reviewed_at: status === 'UPLOADED' ? null : new Date(createdAt),
      rejection_reason: status === 'REJECTED' ? 'Unreadable' : null,
    }));
  }

  it('approves the rider once every current document is approved and notifies once', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      reviewed_at: new Date('2026-09-21T10:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(catalog('APPROVED'));
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'OFFLINE',
    });

    const result = await service.decideForAdmin(adminAuth(), documentId, 'APPROVED');

    expect(files.recordDocumentDecision).toHaveBeenCalledWith(
      expect.objectContaining({
        source: 'ADMIN',
        adminProfileId: adminId,
        status: 'APPROVED',
        rejectionReason: null,
      }),
      {},
    );
    expect(files.updateRiderVerification).toHaveBeenCalledWith(
      expect.objectContaining({
        approvalStatus: 'APPROVED',
        onboardingKycStatus: 'APPROVED',
      }),
      {},
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'RIDER_DOCUMENT_APPROVED',
        entityType: 'RIDER_DOCUMENT',
        entityId: documentId,
        category: 'ADMIN',
      }),
      {},
    );
    expect(result.approval_status).toBe('APPROVED');
    expect(result.document.reviewer_admin_profile_id).toBe(adminId);
    expect(result.document).not.toHaveProperty('storage_key');
    expect(notifications.notifyIfRecipient).toHaveBeenCalledTimes(2);
    expect(notifications.notifyIfRecipient).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'RIDER_DOCUMENT_APPROVED',
        documentName: 'Aadhaar (front)',
      }),
      postgres,
    );
    expect(notifications.notifyIfRecipient).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'RIDER_PROFILE_VERIFIED' }),
      postgres,
    );
  });

  it('does not notify when an already verified rider is approved again', async () => {
    files.findRiderDocument.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
    });
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      reviewed_at: new Date('2026-09-21T11:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(catalog('APPROVED'));
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
    });

    await service.decideForAdmin(adminAuth(), documentId, 'APPROVED');

    expect(notifications.notifyIfRecipient).not.toHaveBeenCalled();
    expect(files.updateRiderVerification).not.toHaveBeenCalled();
  });

  it('rejects without a reason and does not write a decision', async () => {
    await expect(
      service.decideForAdmin(adminAuth(), documentId, 'REJECTED', '   '),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    expect(postgres.transaction).not.toHaveBeenCalled();
  });

  it('rejects a document, drops approval, and notifies with the reason', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'REJECTED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      rejection_reason: 'Photo is blurry',
      reviewed_at: new Date('2026-09-21T12:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(
      catalog('APPROVED').map((row) =>
        row.document_type === 'AADHAAR_FRONT'
          ? { ...row, status: 'REJECTED' as const, rejection_reason: 'Photo is blurry' }
          : row,
      ),
    );
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
    });

    await service.decideForAdmin(adminAuth(), documentId, 'REJECTED', 'Photo is blurry');

    expect(files.updateRiderVerification).toHaveBeenCalledWith(
      expect.objectContaining({
        approvalStatus: 'REJECTED',
        onboardingKycStatus: 'REJECTED',
        onlineStatus: 'OFFLINE',
      }),
      {},
    );
    expect(notifications.notifyIfRecipient).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'RIDER_DOCUMENT_REJECTED',
        reason: 'Photo is blurry',
        documentName: 'Aadhaar (front)',
      }),
      postgres,
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'RIDER_DOCUMENT_REJECTED',
        reason: 'Photo is blurry',
      }),
      {},
    );
  });

  it('does not send a second rejection notification for the same rejected row', async () => {
    files.findRiderDocument.mockResolvedValue({
      ...documentRow(),
      status: 'REJECTED',
    });
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'REJECTED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      rejection_reason: 'Still blurry',
      reviewed_at: new Date('2026-09-21T13:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(catalog('REJECTED'));
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'REJECTED',
      onboarding_kyc_status: 'REJECTED',
      online_status: 'OFFLINE',
    });

    await service.decideForAdmin(adminAuth(), documentId, 'REJECTED', 'Still blurry');

    expect(notifications.notifyIfRecipient).not.toHaveBeenCalled();
  });

  it('keeps a suspended rider suspended when documents become approved', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      reviewed_at: new Date('2026-09-21T14:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(catalog('APPROVED'));
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'SUSPENDED',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'ONLINE',
    });

    const result = await service.decideForAdmin(adminAuth(), documentId, 'APPROVED');

    expect(result.approval_status).toBe('SUSPENDED');
    expect(files.updateRiderVerification).toHaveBeenCalledWith(
      expect.objectContaining({
        approvalStatus: 'SUSPENDED',
        onboardingKycStatus: 'APPROVED',
        onlineStatus: 'OFFLINE',
      }),
      {},
    );
    // Document approval still notifies even when rider stays SUSPENDED.
    expect(notifications.notifyIfRecipient).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'RIDER_DOCUMENT_APPROVED',
        documentName: 'Aadhaar (front)',
      }),
      postgres,
    );
    expect(notifications.notifyIfRecipient).not.toHaveBeenCalledWith(
      expect.objectContaining({ type: 'RIDER_PROFILE_VERIFIED' }),
      postgres,
    );
  });

  it('records an IDfy decision through the same approval update', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
      verification_source: 'IDFY',
      reviewer_admin_profile_id: null,
      reviewed_at: new Date('2026-09-21T15:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(
      catalog('APPROVED').map((row) => ({
        ...row,
        verification_source: 'IDFY' as const,
        reviewer_admin_profile_id: null,
      })),
    );
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'OFFLINE',
    });

    const result = await service.decideDocument({
      documentId,
      decision: 'APPROVED',
      source: 'IDFY',
      adminProfileId: null,
    });

    expect(files.recordDocumentDecision).toHaveBeenCalledWith(
      expect.objectContaining({ source: 'IDFY', adminProfileId: null, status: 'APPROVED' }),
      {},
    );
    expect(result.approval_status).toBe('APPROVED');
    expect(result.document.verification_source).toBe('IDFY');
  });

  it('still returns the decision when notification delivery fails', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'REJECTED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      rejection_reason: 'Expired',
      reviewed_at: new Date('2026-09-21T16:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(catalog('REJECTED'));
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'OFFLINE',
    });
    notifications.notifyIfRecipient.mockRejectedValue(new Error('push down'));

    const result = await service.decideForAdmin(adminAuth(), documentId, 'REJECTED', 'Expired');

    expect(result.document.status).toBe('REJECTED');
    expect(result.approval_status).toBe('REJECTED');
  });

  it('drops a verified rider when a replacement upload is the latest row', async () => {
    const older = new Date('2026-09-19T08:00:00.000Z');
    const newer = new Date('2026-09-22T08:00:00.000Z');
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
    });
    files.listRiderDocuments.mockResolvedValue([
      ...catalog('APPROVED', older.toISOString()).filter((row) => row.document_type !== 'PAN_FRONT'),
      {
        ...documentRow(),
        document_type: 'PAN_FRONT',
        status: 'APPROVED',
        created_at: older,
        verification_source: 'ADMIN',
        reviewer_admin_profile_id: adminId,
        reviewed_at: older,
      },
      {
        ...documentRow(),
        rider_document_id: 'new-pan',
        document_type: 'PAN_FRONT',
        status: 'UPLOADED',
        created_at: newer,
      },
    ]);

    await service.uploadOwn(riderAuth(), 'PAN_FRONT', {
      buffer: jpeg(),
      mimetype: 'image/jpeg',
      originalname: 'pan.jpg',
    });

    expect(files.updateRiderVerification).toHaveBeenCalledWith(
      expect.objectContaining({
        approvalStatus: 'PENDING',
        onboardingKycStatus: 'SUBMITTED',
        onlineStatus: 'OFFLINE',
      }),
      {},
    );
    expect(notifications.notifyIfRecipient).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'RIDER_DOCUMENT_SUBMITTED',
      }),
      postgres,
    );
  });

  it('lets an unverified rider upload and refuses an approved rider', async () => {
    files.findRiderVerification.mockResolvedValue({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'OFFLINE',
    });
    await service.uploadOwn(riderAuth(), 'AADHAAR_FRONT', {
      buffer: jpeg(),
      mimetype: 'image/jpeg',
      originalname: 'aadhaar.jpg',
    });
    expect(storage.putObject).toHaveBeenCalled();

    storage.putObject.mockClear();
    files.findRiderVerification.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
    });
    await expect(
      service.uploadOwn(riderAuth(), 'AADHAAR_FRONT', {
        buffer: jpeg(),
        mimetype: 'image/jpeg',
        originalname: 'aadhaar.jpg',
      }),
    ).rejects.toMatchObject({ code: 'RIDER_DOCUMENTS_LOCKED', status: 409 });
    expect(storage.putObject).not.toHaveBeenCalled();
    expect(files.recordDocumentDecision).not.toHaveBeenCalled();
    expect(files.updateRiderVerification).not.toHaveBeenCalled();
  });

  it('still lets an admin review documents while the rider is approved', async () => {
    files.findRiderDocument.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
    });
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      reviewed_at: new Date('2026-09-21T10:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(catalog('APPROVED'));
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
      verification_reopened_at: null,
    });

    const result = await service.decideForAdmin(adminAuth(), documentId, 'APPROVED');

    expect(result.approval_status).toBe('APPROVED');
  });

  it('reopens an approved rider without a second status and forces offline', async () => {
    const reopenedAt = new Date('2026-09-25T12:00:00.000Z');
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
      verification_reopened_at: null,
    });
    files.reopenRiderVerification.mockResolvedValue({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'OFFLINE',
      verification_reopened_at: reopenedAt,
      preferred_language: 'en',
      profile_picture_file_id: null,
    });

    const result = await service.reopenForAdmin(adminAuth(), riderId);

    expect(result).toEqual({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'OFFLINE',
      documents_locked: false,
    });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'RIDER_VERIFICATION_REOPENED',
        entityType: 'RIDER_PROFILE',
        entityId: riderId,
        category: 'ADMIN',
      }),
      {},
    );
    expect(notifications.notifyIfRecipient).not.toHaveBeenCalled();
  });

  it('does not reopen a suspended rider', async () => {
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'SUSPENDED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'OFFLINE',
    });

    await expect(service.reopenForAdmin(adminAuth(), riderId)).rejects.toMatchObject({
      code: 'RIDER_NOT_ELIGIBLE',
    });
    expect(files.reopenRiderVerification).not.toHaveBeenCalled();
  });

  it('uploads, replaces, and signs the rider profile picture without touching approval', async () => {
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
    });
    files.findProfilePicture.mockResolvedValueOnce(null);
    const first = await service.uploadProfilePicture(riderAuth(), {
      buffer: jpeg(),
      mimetype: 'image/jpeg',
      originalname: 'me.jpg',
    });
    expect(files.setProfilePicture).toHaveBeenCalledWith(riderId, expect.any(String), {});
    expect(files.insertStoredFile).toHaveBeenCalledWith(
      expect.objectContaining({ purpose: 'OTHER' }),
      {},
    );
    expect(files.updateRiderVerification).not.toHaveBeenCalled();
    expect(first.approval_status).toBe('APPROVED');
    expect(first.download_url).toContain('X-Amz-Signature');
    expect(files.deleteStoredFile).not.toHaveBeenCalled();

    files.findProfilePicture.mockResolvedValueOnce({
      file_id: fileId,
      storage_key: `riders/${riderId}/profile/old/me.jpg`,
      content_type: 'image/jpeg',
    });
    await service.uploadProfilePicture(riderAuth(), {
      buffer: jpeg(),
      mimetype: 'image/jpeg',
      originalname: 'me2.jpg',
    });
    expect(files.deleteStoredFile).toHaveBeenCalledWith(fileId, {});
    expect(storage.deleteObject).toHaveBeenCalledWith(
      `riders/${riderId}/profile/old/me.jpg`,
    );

    files.findProfilePicture.mockResolvedValue({
      file_id: fileId,
      storage_key: `riders/${riderId}/profile/${fileId}/me.jpg`,
      content_type: 'image/jpeg',
    });
    const viewed = await service.viewOwnProfilePicture(riderAuth());
    expect(viewed.download_url).toContain('X-Amz-Signature');
    expect(viewed).not.toHaveProperty('storage_key');
  });

  it('keeps the new profile picture when deleting the previous object fails', async () => {
    const previousKey = `riders/${riderId}/profile/old/me.jpg`;
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
    });
    files.findProfilePicture.mockResolvedValue({
      file_id: fileId,
      storage_key: previousKey,
      content_type: 'image/jpeg',
    });
    storage.deleteObject.mockRejectedValue(new Error('bucket down'));
    const errorSpy = jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);

    try {
      const result = await service.uploadProfilePicture(riderAuth(), {
        buffer: jpeg(),
        mimetype: 'image/jpeg',
        originalname: 'me2.jpg',
      });
      const savedId = files.setProfilePicture.mock.calls.at(-1)?.[1];

      expect(result.profile_picture_file_id).toBe(savedId);
      expect(savedId).not.toBe(fileId);
      expect(files.deleteStoredFile).toHaveBeenCalledWith(fileId, {});
      expect(storage.deleteObject).toHaveBeenCalledWith(previousKey);
      expect(files.setProfilePicture.mock.invocationCallOrder[0]).toBeLessThan(
        storage.deleteObject.mock.invocationCallOrder[0],
      );
      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining(previousKey),
        expect.stringContaining('bucket down'),
      );
      expect(result.download_url).toContain('X-Amz-Signature');
    } finally {
      errorSpy.mockRestore();
    }
  });

  it('refuses another rider role and lets an admin open a signed picture', async () => {
    await expect(
      service.uploadProfilePicture(
        { ...riderAuth(), role: 'CUSTOMER' },
        { buffer: jpeg(), mimetype: 'image/jpeg', originalname: 'me.jpg' },
      ),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
    expect(storage.putObject).not.toHaveBeenCalled();

    files.riderExists.mockResolvedValue(true);
    files.findProfilePicture.mockResolvedValue({
      file_id: fileId,
      storage_key: `riders/${riderId}/profile/${fileId}/me.jpg`,
      content_type: 'image/jpeg',
    });
    const adminView = await service.viewProfilePictureForAdmin(adminAuth(), riderId);
    expect(adminView.download_url).toContain('X-Amz-Signature');
    expect(storage.getSignedGetUrl).toHaveBeenCalled();
  });

  it('lists real document ids and marks only the latest row of each type current', async () => {
    const older = {
      ...documentRow(),
      rider_document_id: 'older-aadhaar',
      created_at: new Date('2026-09-18T08:00:00.000Z'),
      status: 'REJECTED' as const,
      rejection_reason: 'Blurry',
      verification_source: 'ADMIN' as const,
      reviewer_admin_profile_id: adminId,
      reviewed_at: new Date('2026-09-18T09:00:00.000Z'),
    };
    const newer = {
      ...documentRow(),
      created_at: new Date('2026-09-20T08:00:00.000Z'),
    };
    files.riderExists.mockResolvedValue(true);
    files.listRiderDocuments.mockResolvedValue([newer, older]);
    files.findRiderVerification.mockResolvedValue({
      approval_status: 'PENDING',
      onboarding_kyc_status: 'SUBMITTED',
      online_status: 'OFFLINE',
      verification_reopened_at: null,
      preferred_language: 'en',
      profile_picture_file_id: null,
    });

    const listed = await service.listForAdmin(adminAuth(), riderId);

    expect(listed.documents.map((row) => row.rider_document_id)).toEqual([
      documentId,
      'older-aadhaar',
    ]);
    expect(listed.documents[0].is_current).toBe(true);
    expect(listed.documents[1].is_current).toBe(false);
    expect(listed.documents[0].original_filename).toBe('aadhaar.jpg');
    expect(listed.documents[0]).not.toHaveProperty('storage_key');
    expect(listed.approval_status).toBe('PENDING');
  });

  it('returns an inline signed preview for an admin and attachment when asked', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());

    const preview = await service.downloadForAdmin(adminAuth(), documentId);
    expect(preview.download_url).toContain('X-Amz-Signature');
    expect(preview.content_disposition).toBe('inline');
    expect(preview.content_type).toBe('image/jpeg');
    expect(preview.original_filename).toBe('aadhaar.jpg');
    expect(preview).not.toHaveProperty('storage_key');
    expect(storage.getSignedGetUrl).toHaveBeenCalledWith(
      `riders/${riderId}/documents/${documentId}/aadhaar.jpg`,
      'aadhaar.jpg',
      { disposition: 'inline', contentType: 'image/jpeg' },
    );

    await service.downloadForAdmin(adminAuth(), documentId, 'attachment');
    expect(storage.getSignedGetUrl).toHaveBeenLastCalledWith(
      `riders/${riderId}/documents/${documentId}/aadhaar.jpg`,
      'aadhaar.jpg',
      { disposition: 'attachment', contentType: 'image/jpeg' },
    );
  });

  it('returns 404 for a missing admin document and 400 for a bad disposition', async () => {
    files.findRiderDocument.mockResolvedValue(null);
    await expect(
      service.downloadForAdmin(adminAuth(), documentId),
    ).rejects.toMatchObject({ code: 'NOT_FOUND', status: 404 });

    files.findRiderDocument.mockResolvedValue(documentRow());
    await expect(
      service.downloadForAdmin(adminAuth(), documentId, 'public'),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });
  });

  it('reports unconfigured storage when an admin preview cannot be signed', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    storage.getSignedGetUrl.mockRejectedValue(
      new ApiError('STORAGE_UNAVAILABLE', 'Document storage is unavailable. Try again shortly.', 503),
    );
    await expect(
      service.downloadForAdmin(adminAuth(), documentId, 'inline'),
    ).rejects.toMatchObject({ code: 'STORAGE_UNAVAILABLE', status: 503 });
  });

  it('refuses a non-admin preview', async () => {
    await expect(
      service.downloadForAdmin(riderAuth(), documentId),
    ).rejects.toMatchObject({ code: 'FORBIDDEN', status: 403 });
    expect(storage.getSignedGetUrl).not.toHaveBeenCalled();
  });

  it('keeps the rider pending when one required document is still uploaded', async () => {
    files.findRiderDocument.mockResolvedValue(documentRow());
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      status: 'APPROVED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      reviewed_at: new Date('2026-09-21T10:00:00.000Z'),
    });
    files.listRiderDocuments.mockResolvedValue(
      catalog('APPROVED').map((row) =>
        row.document_type === 'BANK_PROOF'
          ? {
              ...row,
              status: 'UPLOADED' as const,
              verification_source: null,
              reviewer_admin_profile_id: null,
              reviewed_at: null,
              rejection_reason: null,
            }
          : row,
      ),
    );
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'APPROVED',
      onboarding_kyc_status: 'APPROVED',
      online_status: 'ONLINE',
    });

    const result = await service.decideForAdmin(adminAuth(), documentId, 'APPROVED');

    expect(result.approval_status).toBe('PENDING');
    expect(result.onboarding_kyc_status).toBe('SUBMITTED');
    expect(files.updateRiderVerification).toHaveBeenCalledWith(
      expect.objectContaining({
        approvalStatus: 'PENDING',
        onboardingKycStatus: 'SUBMITTED',
        onlineStatus: 'OFFLINE',
      }),
      {},
    );
  });

  it('approves from the latest replacement and ignores an older rejection', async () => {
    const older = new Date('2026-09-18T08:00:00.000Z');
    const newer = new Date('2026-09-22T08:00:00.000Z');
    files.findRiderDocument.mockResolvedValue({
      ...documentRow(),
      document_type: 'PAN_FRONT',
      status: 'UPLOADED',
      created_at: newer,
    });
    files.recordDocumentDecision.mockResolvedValue({
      ...documentRow(),
      document_type: 'PAN_FRONT',
      status: 'APPROVED',
      verification_source: 'ADMIN',
      reviewer_admin_profile_id: adminId,
      reviewed_at: newer,
      created_at: newer,
    });
    files.listRiderDocuments.mockResolvedValue([
      ...catalog('APPROVED', older.toISOString()).filter((row) => row.document_type !== 'PAN_FRONT'),
      {
        ...documentRow(),
        document_type: 'PAN_FRONT',
        status: 'REJECTED',
        created_at: older,
        verification_source: 'ADMIN',
        reviewer_admin_profile_id: adminId,
        reviewed_at: older,
        rejection_reason: 'Expired',
      },
      {
        ...documentRow(),
        document_type: 'PAN_FRONT',
        status: 'APPROVED',
        created_at: newer,
        verification_source: 'ADMIN',
        reviewer_admin_profile_id: adminId,
        reviewed_at: newer,
        rejection_reason: null,
      },
    ]);
    files.lockRiderProfile.mockResolvedValue({
      approval_status: 'REJECTED',
      onboarding_kyc_status: 'REJECTED',
      online_status: 'OFFLINE',
    });

    const result = await service.decideForAdmin(adminAuth(), documentId, 'APPROVED');

    expect(result.approval_status).toBe('APPROVED');
    expect(result.onboarding_kyc_status).toBe('APPROVED');
    expect(files.updateRiderVerification).toHaveBeenCalledWith(
      expect.objectContaining({
        approvalStatus: 'APPROVED',
        onboardingKycStatus: 'APPROVED',
      }),
      {},
    );
  });
});
