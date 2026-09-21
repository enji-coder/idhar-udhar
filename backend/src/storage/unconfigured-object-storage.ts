import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { ObjectStorage, PutObjectInput } from './object-storage';

const UNAVAILABLE =
  'Document storage is unavailable. Try again shortly.';

export class UnconfiguredObjectStorage implements ObjectStorage {
  async putObject(_input: PutObjectInput): Promise<void> {
    throw new ApiError(ErrorCodes.STORAGE_UNAVAILABLE, UNAVAILABLE, 503);
  }

  async deleteObject(_key: string): Promise<void> {
    throw new ApiError(ErrorCodes.STORAGE_UNAVAILABLE, UNAVAILABLE, 503);
  }

  async getSignedGetUrl(
    _key: string,
    _downloadFileName?: string,
  ): Promise<{ url: string; expiresInSeconds: number }> {
    throw new ApiError(ErrorCodes.STORAGE_UNAVAILABLE, UNAVAILABLE, 503);
  }
}
