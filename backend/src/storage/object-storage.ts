export const OBJECT_STORAGE = Symbol('OBJECT_STORAGE');

export type PutObjectInput = {
  key: string;
  body: Buffer;
  contentType: string;
  downloadFileName?: string;
};

export interface ObjectStorage {
  putObject(input: PutObjectInput): Promise<void>;
  deleteObject(key: string): Promise<void>;
  getSignedGetUrl(key: string, downloadFileName?: string): Promise<{
    url: string;
    expiresInSeconds: number;
  }>;
}
