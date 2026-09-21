import { loadAppConfig } from './configuration';

describe('S3 documents storage configuration', () => {
  const originalBucket = process.env.S3_DOCUMENTS_BUCKET;
  const originalRegion = process.env.AWS_REGION;
  const originalTtl = process.env.S3_SIGNED_URL_TTL_SECONDS;

  function restore(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }

  afterEach(() => {
    restore('S3_DOCUMENTS_BUCKET', originalBucket);
    restore('AWS_REGION', originalRegion);
    restore('S3_SIGNED_URL_TTL_SECONDS', originalTtl);
  });

  it('stays unconfigured when the documents bucket is empty', () => {
    delete process.env.S3_DOCUMENTS_BUCKET;
    delete process.env.AWS_REGION;
    const config = loadAppConfig();
    expect(config.storage.provider).toBe('unconfigured');
    expect(config.storage.bucket).toBeNull();
    expect(config.storage.signedUrlTtlSeconds).toBe(300);
  });

  it('enables private S3 when the bucket and region are set', () => {
    process.env.S3_DOCUMENTS_BUCKET = 'idhar-udhar-prod-documents';
    process.env.AWS_REGION = 'ap-south-1';
    const config = loadAppConfig();
    expect(config.storage.provider).toBe('s3');
    expect(config.storage.bucket).toBe('idhar-udhar-prod-documents');
    expect(config.storage.region).toBe('ap-south-1');
    expect(config).not.toHaveProperty('storage.accessKeyId');
    expect(config).not.toHaveProperty('storage.secretAccessKey');
  });

  it('refuses a bucket without AWS_REGION', () => {
    process.env.S3_DOCUMENTS_BUCKET = 'idhar-udhar-prod-documents';
    delete process.env.AWS_REGION;
    expect(() => loadAppConfig()).toThrow(/AWS_REGION/);
  });

  it('refuses long-lived signed URL TTLs', () => {
    process.env.S3_DOCUMENTS_BUCKET = 'idhar-udhar-prod-documents';
    process.env.AWS_REGION = 'ap-south-1';
    process.env.S3_SIGNED_URL_TTL_SECONDS = '3600';
    expect(() => loadAppConfig()).toThrow(/S3_SIGNED_URL_TTL_SECONDS/);
  });
});
