import { ApiError } from '../common/errors/api-error';
import { AuthContext } from '../auth/types/auth-context';
import { PostgresService } from '../database/postgres.service';
import { ObjectStorage } from '../storage/object-storage';
import { FilesRepository, RiderDocumentRow } from './files.repository';
import { RiderDocumentsService } from './rider-documents.service';

const riderId = '11111111-1111-4111-8111-111111111111';
const otherRiderId = '55555555-5555-4555-8555-555555555555';
const documentId = '22222222-2222-4222-8222-222222222222';
const fileId = '66666666-6666-4666-8666-666666666666';

function jpeg(): Buffer {
  const buffer = Buffer.alloc(32, 0);
  buffer[0] = 0xff;
  buffer[1] = 0xd8;
  buffer[2] = 0xff;
  return buffer;
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
  );

  beforeEach(() => {
    jest.clearAllMocks();
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
    );
    expect(result.download_url_expires_in).toBe(300);
    expect(result.download_url).toContain('X-Amz-Signature');
  });
});
