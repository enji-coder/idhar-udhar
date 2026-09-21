import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { safeFileName } from './object-key';

export const MAX_DOCUMENT_BYTES = 5 * 1024 * 1024;

export const ALLOWED_CONTENT_TYPES = [
  'image/jpeg',
  'image/png',
  'application/pdf',
] as const;

export type AllowedContentType = (typeof ALLOWED_CONTENT_TYPES)[number];

export const RIDER_DOCUMENT_TYPES = [
  'AADHAAR_FRONT',
  'AADHAAR_BACK',
  'PAN_FRONT',
  'DRIVING_LICENSE_FRONT',
  'DRIVING_LICENSE_BACK',
  'VEHICLE_RC_FRONT',
  'VEHICLE_RC_BACK',
  'BANK_PROOF',
] as const;

export type RiderDocumentType = (typeof RIDER_DOCUMENT_TYPES)[number];

const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff]);
const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const PDF_MAGIC = Buffer.from('%PDF');

export type UploadedBinary = {
  buffer: Buffer;
  mimetype?: string;
  originalname?: string;
  size?: number;
};

export type ValidatedUpload = {
  buffer: Buffer;
  contentType: AllowedContentType;
  sizeBytes: number;
  safeFileName: string;
};

function sniffContentType(buffer: Buffer): AllowedContentType | null {
  if (buffer.length >= JPEG_MAGIC.length && buffer.subarray(0, 3).equals(JPEG_MAGIC)) {
    return 'image/jpeg';
  }
  if (buffer.length >= PNG_MAGIC.length && buffer.subarray(0, 8).equals(PNG_MAGIC)) {
    return 'image/png';
  }
  if (buffer.length >= PDF_MAGIC.length && buffer.subarray(0, 4).equals(PDF_MAGIC)) {
    return 'application/pdf';
  }
  return null;
}

export function isRiderDocumentType(value: string): value is RiderDocumentType {
  return (RIDER_DOCUMENT_TYPES as readonly string[]).includes(value);
}

export function validateUpload(file: UploadedBinary | undefined): ValidatedUpload {
  if (!file || !file.buffer || file.buffer.length === 0) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'A file is required',
      400,
    );
  }
  const sizeBytes = file.buffer.length;
  if (sizeBytes > MAX_DOCUMENT_BYTES) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'File exceeds the maximum allowed size',
      400,
    );
  }
  const sniffed = sniffContentType(file.buffer);
  if (!sniffed) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'File type is not allowed',
      400,
    );
  }
  const declared = (file.mimetype ?? '').toLowerCase();
  if (declared && declared !== sniffed) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'File type is not allowed',
      400,
    );
  }
  return {
    buffer: file.buffer,
    contentType: sniffed,
    sizeBytes,
    safeFileName: safeFileName(file.originalname, sniffed),
  };
}
