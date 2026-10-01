import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { OBJECT_STORAGE, ObjectStorage, PutObjectInput } from '../src/storage/object-storage';
import {
  issueAdminSession,
  issueCustomerSession,
  issueRiderSession,
} from './helpers';

function jpeg(): Buffer {
  const buffer = Buffer.alloc(64, 0);
  buffer[0] = 0xff;
  buffer[1] = 0xd8;
  buffer[2] = 0xff;
  return buffer;
}

function fakeStorage(): ObjectStorage & { objects: Map<string, Buffer> } {
  const objects = new Map<string, Buffer>();
  return {
    objects,
    async putObject(input: PutObjectInput) {
      objects.set(input.key, Buffer.from(input.body));
    },
    async deleteObject(key: string) {
      objects.delete(key);
    },
    async getSignedGetUrl(key: string) {
      if (!objects.has(key)) {
        throw new Error('missing object');
      }
      return {
        url: `https://example.invalid/${encodeURIComponent(key)}?X-Amz-Signature=test`,
        expiresInSeconds: 300,
      };
    },
  };
}

describe('Rider documents and private S3 (e2e)', () => {
  let app: INestApplication;
  let storage: ReturnType<typeof fakeStorage>;

  beforeAll(async () => {
    storage = fakeStorage();
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(OBJECT_STORAGE)
      .useValue(storage)
      .compile();
    app = moduleRef.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects unauthenticated document access', async () => {
    const res = await request(app.getHttpServer()).get('/v1/rider/documents');
    expect(res.status).toBe(401);
  });

  it('rejects a customer uploading rider KYC', async () => {
    const customer = await issueCustomerSession(app);
    const before = storage.objects.size;
    const res = await request(app.getHttpServer())
      .post('/v1/rider/documents')
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .field('document_type', 'AADHAAR_FRONT')
      .attach('file', jpeg(), { filename: 'aadhaar.jpg', contentType: 'image/jpeg' });
    expect(res.status).toBe(403);
    expect(storage.objects.size).toBe(before);
  });

  it('uploads a rider document to mocked S3 and persists metadata', async () => {
    const rider = await issueRiderSession(app);
    const uploaded = await request(app.getHttpServer())
      .post('/v1/rider/documents')
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`)
      .field('document_type', 'AADHAAR_FRONT')
      .attach('file', jpeg(), { filename: 'aadhaar.jpg', contentType: 'image/jpeg' });
    expect(uploaded.status).toBe(201);
    expect(uploaded.body.document_type).toBe('AADHAAR_FRONT');
    expect(uploaded.body.status).toBe('UPLOADED');
    expect(uploaded.body.download_url).toBeUndefined();
    expect(uploaded.body.storage_key).toBeUndefined();
    expect(storage.objects.size).toBe(1);

    const listed = await request(app.getHttpServer())
      .get('/v1/rider/documents')
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(listed.status).toBe(200);
    expect(listed.body.documents).toHaveLength(1);

    const downloaded = await request(app.getHttpServer())
      .get(`/v1/rider/documents/${uploaded.body.rider_document_id}`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(downloaded.status).toBe(200);
    expect(downloaded.body.download_url_expires_in).toBe(300);
    expect(downloaded.body.download_url).toContain('X-Amz-Signature=test');

    const stranger = await issueRiderSession(app);
    const forbidden = await request(app.getHttpServer())
      .get(`/v1/rider/documents/${uploaded.body.rider_document_id}`)
      .set('Authorization', `Bearer ${stranger.tokens.accessToken}`);
    expect(forbidden.status).toBe(403);

    const admin = await issueAdminSession(app);
    const adminView = await request(app.getHttpServer())
      .get(`/v1/admin/documents/${uploaded.body.rider_document_id}`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`);
    expect(adminView.status).toBe(200);
    expect(adminView.body.rider_profile_id).toBe(rider.profileId);
    expect(adminView.body.content_disposition).toBe('inline');
    expect(adminView.body.rider_document_id).toBe(uploaded.body.rider_document_id);
    expect(adminView.body.storage_key).toBeUndefined();
    expect(adminView.body.original_filename).toBe('aadhaar.jpg');

    const attachment = await request(app.getHttpServer())
      .get(`/v1/admin/documents/${uploaded.body.rider_document_id}?disposition=attachment`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`);
    expect(attachment.status).toBe(200);
    expect(attachment.body.content_disposition).toBe('attachment');

    const badDisposition = await request(app.getHttpServer())
      .get(`/v1/admin/documents/${uploaded.body.rider_document_id}?disposition=public`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`);
    expect(badDisposition.status).toBe(400);

    const missing = await request(app.getHttpServer())
      .get('/v1/admin/documents/99999999-9999-4999-8999-999999999999')
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`);
    expect(missing.status).toBe(404);

    const listed = await request(app.getHttpServer())
      .get(`/v1/admin/riders/${rider.profileId}/documents`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`);
    expect(listed.status).toBe(200);
    expect(listed.body.documents[0].rider_document_id).toBe(uploaded.body.rider_document_id);
    expect(listed.body.documents[0].is_current).toBe(true);
    expect(listed.body.documents[0].storage_key).toBeUndefined();

    const emptyReject = await request(app.getHttpServer())
      .post(`/v1/admin/documents/${uploaded.body.rider_document_id}/reject`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`)
      .send({ rejection_reason: '   ' });
    expect(emptyReject.status).toBe(400);

    const approved = await request(app.getHttpServer())
      .post(`/v1/admin/documents/${uploaded.body.rider_document_id}/approve`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`)
      .send({});
    expect(approved.status).toBe(200);
    expect(approved.body.document.status).toBe('APPROVED');
    expect(approved.body.document.reviewer_admin_profile_id).toBe(admin.profileId);
    expect(approved.body.document.reviewed_at).toBeTruthy();
    expect(approved.body.document.rejection_reason).toBeNull();
    expect(approved.body.approval_status).toBe('PENDING');

    const rejected = await request(app.getHttpServer())
      .post(`/v1/admin/documents/${uploaded.body.rider_document_id}/reject`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`)
      .send({ rejection_reason: 'Driving licence image is unclear' });
    expect(rejected.status).toBe(200);
    expect(rejected.body.document.status).toBe('REJECTED');
    expect(rejected.body.document.rejection_reason).toBe('Driving licence image is unclear');
    expect(rejected.body.document.reviewer_admin_profile_id).toBe(admin.profileId);
    expect(rejected.body.approval_status).toBe('REJECTED');
    expect(rejected.body.onboarding_kyc_status).toBe('REJECTED');
  });

  it('rejects executable uploads', async () => {
    const rider = await issueRiderSession(app);
    const res = await request(app.getHttpServer())
      .post('/v1/rider/documents')
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`)
      .field('document_type', 'AADHAAR_FRONT')
      .attach('file', Buffer.from('MZ executable'), {
        filename: 'payload.exe',
        contentType: 'application/octet-stream',
      });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });
});
