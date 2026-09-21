import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppLogger } from '../common/logger/app-logger';
import { ObjectStorage, PutObjectInput } from './object-storage';

export type S3StorageOptions = {
  bucket: string;
  region: string;
  signedUrlTtlSeconds: number;
};

export type S3Sender = Pick<S3Client, 'send'>;

export type SignGetUrl = (
  client: S3Sender,
  command: GetObjectCommand,
  options: { expiresIn: number },
) => Promise<string>;

const UNAVAILABLE =
  'Document storage is unavailable. Try again shortly.';

export class S3ObjectStorage implements ObjectStorage {
  constructor(
    private readonly options: S3StorageOptions,
    private readonly logger: AppLogger,
    private readonly client: S3Sender = new S3Client({
      region: options.region,
    }),
    private readonly sign: SignGetUrl = ((c, command, opts) =>
      getSignedUrl(c as S3Client, command, opts)) as SignGetUrl,
  ) {}

  async putObject(input: PutObjectInput): Promise<void> {
    try {
      await this.client.send(
        new PutObjectCommand({
          Bucket: this.options.bucket,
          Key: input.key,
          Body: input.body,
          ContentType: input.contentType,
          ServerSideEncryption: 'AES256',
        }),
      );
    } catch (err) {
      this.logger.error('s3_put_failed', {
        err: err instanceof Error ? err.name : 'unknown',
      });
      throw new ApiError(ErrorCodes.STORAGE_UNAVAILABLE, UNAVAILABLE, 503);
    }
  }

  async deleteObject(key: string): Promise<void> {
    try {
      await this.client.send(
        new DeleteObjectCommand({
          Bucket: this.options.bucket,
          Key: key,
        }),
      );
    } catch (err) {
      this.logger.error('s3_delete_failed', {
        err: err instanceof Error ? err.name : 'unknown',
      });
      throw new ApiError(ErrorCodes.STORAGE_UNAVAILABLE, UNAVAILABLE, 503);
    }
  }

  async getSignedGetUrl(
    key: string,
    downloadFileName?: string,
  ): Promise<{ url: string; expiresInSeconds: number }> {
    const expiresIn = this.options.signedUrlTtlSeconds;
    try {
      const url = await this.sign(
        this.client,
        new GetObjectCommand({
          Bucket: this.options.bucket,
          Key: key,
          ResponseCacheControl: 'private, no-store',
          ResponseContentDisposition: downloadFileName
            ? `attachment; filename="${downloadFileName}"`
            : undefined,
        }),
        { expiresIn },
      );
      return { url, expiresInSeconds: expiresIn };
    } catch (err) {
      this.logger.error('s3_sign_failed', {
        err: err instanceof Error ? err.name : 'unknown',
      });
      throw new ApiError(ErrorCodes.STORAGE_UNAVAILABLE, UNAVAILABLE, 503);
    }
  }
}
