import { MAX_DOCUMENT_BYTES, validateUpload } from './file-validation';

function jpeg(size = 32): Buffer {
  const buffer = Buffer.alloc(size, 0);
  buffer[0] = 0xff;
  buffer[1] = 0xd8;
  buffer[2] = 0xff;
  return buffer;
}

describe('file-validation', () => {
  it('accepts a JPEG within the size limit', () => {
    const result = validateUpload({
      buffer: jpeg(),
      mimetype: 'image/jpeg',
      originalname: 'aadhaar.jpg',
    });
    expect(result.contentType).toBe('image/jpeg');
    expect(result.safeFileName).toBe('aadhaar.jpg');
  });

  it('rejects an empty file', () => {
    expect(() =>
      validateUpload({ buffer: Buffer.alloc(0), mimetype: 'image/jpeg' }),
    ).toThrow(/A file is required/);
  });

  it('rejects files over the size limit', () => {
    expect(() =>
      validateUpload({
        buffer: jpeg(MAX_DOCUMENT_BYTES + 1),
        mimetype: 'image/jpeg',
      }),
    ).toThrow(/maximum allowed size/);
  });

  it('rejects executable content that is not an allowed document type', () => {
    expect(() =>
      validateUpload({
        buffer: Buffer.from('MZ\0\0this-is-not-an-image'),
        mimetype: 'application/octet-stream',
        originalname: 'payload.exe',
      }),
    ).toThrow(/File type is not allowed/);
  });

  it('rejects a declared JPEG whose magic bytes do not match', () => {
    expect(() =>
      validateUpload({
        buffer: Buffer.from('%PDF-1.4\n'),
        mimetype: 'image/jpeg',
        originalname: 'fake.jpg',
      }),
    ).toThrow(/File type is not allowed/);
  });
});
