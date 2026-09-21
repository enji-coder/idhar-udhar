import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { AppLogger } from '../common/logger/app-logger';
import { S3ObjectStorage, S3Sender } from './s3-object-storage';
import { UnconfiguredObjectStorage } from './unconfigured-object-storage';

describe('S3ObjectStorage', () => {
  const logger = {
    error: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
  } as unknown as AppLogger;

  function storage(send: jest.Mock, sign?: jest.Mock) {
    return new S3ObjectStorage(
      {
        bucket: 'idhar-udhar-prod-documents',
        region: 'ap-south-1',
        signedUrlTtlSeconds: 300,
      },
      logger,
      { send } as unknown as S3Sender,
      sign,
    );
  }

  beforeEach(() => {
    (logger.error as jest.Mock).mockClear();
  });

  it('puts a private object with SSE and without a public ACL', async () => {
    const send = jest.fn(async (command: unknown) => {
      expect(command).toBeInstanceOf(PutObjectCommand);
      const input = (command as PutObjectCommand).input;
      expect(input.Bucket).toBe('idhar-udhar-prod-documents');
      expect(input.Key).toBe('riders/abc/documents/def/aadhaar.jpg');
      expect(input.ContentType).toBe('image/jpeg');
      expect(input.ServerSideEncryption).toBe('AES256');
      expect(input.ACL).toBeUndefined();
      expect(Buffer.isBuffer(input.Body)).toBe(true);
      return {};
    });
    await storage(send).putObject({
      key: 'riders/abc/documents/def/aadhaar.jpg',
      body: Buffer.from([0xff, 0xd8, 0xff]),
      contentType: 'image/jpeg',
    });
    expect(send).toHaveBeenCalledTimes(1);
  });

  it('issues a short-lived presigned GET and does not log the URL', async () => {
    const send = jest.fn();
    const sign = jest.fn(async (_client, command: GetObjectCommand, options) => {
      expect(command).toBeInstanceOf(GetObjectCommand);
      expect(command.input.Bucket).toBe('idhar-udhar-prod-documents');
      expect(command.input.ResponseCacheControl).toBe('private, no-store');
      expect(options.expiresIn).toBe(300);
      return 'https://example.invalid/obj?X-Amz-Signature=secret';
    });
    const result = await storage(send, sign).getSignedGetUrl(
      'orders/o/pod/s/pod.jpg',
      'pod.jpg',
    );
    expect(result).toEqual({
      url: 'https://example.invalid/obj?X-Amz-Signature=secret',
      expiresInSeconds: 300,
    });
    expect(send).not.toHaveBeenCalled();
    expect((logger.error as jest.Mock).mock.calls.join(' ')).not.toContain(
      'X-Amz-Signature',
    );
  });

  it('maps S3 PutObject failures to STORAGE_UNAVAILABLE without logging bytes', async () => {
    const send = jest.fn(async () => {
      throw new Error('AccessDenied');
    });
    await expect(
      storage(send).putObject({
        key: 'k',
        body: Buffer.from('secret-file-bytes'),
        contentType: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'STORAGE_UNAVAILABLE', status: 503 });
    const logged = JSON.stringify((logger.error as jest.Mock).mock.calls);
    expect(logged).not.toContain('secret-file-bytes');
    expect(logged).not.toContain('AccessDenied');
    expect(logged).toContain('s3_put_failed');
  });

  it('deletes an object with the configured private bucket', async () => {
    const send = jest.fn(async (command: unknown) => {
      expect(command).toBeInstanceOf(DeleteObjectCommand);
      expect((command as DeleteObjectCommand).input.Bucket).toBe(
        'idhar-udhar-prod-documents',
      );
      return {};
    });
    await storage(send).deleteObject('riders/abc/documents/def/aadhaar.jpg');
  });
});

describe('UnconfiguredObjectStorage', () => {
  it('fails honestly instead of pretending an upload succeeded', async () => {
    const storage = new UnconfiguredObjectStorage();
    await expect(
      storage.putObject({
        key: 'k',
        body: Buffer.from('x'),
        contentType: 'image/jpeg',
      }),
    ).rejects.toMatchObject({ code: 'STORAGE_UNAVAILABLE', status: 503 });
  });
});
