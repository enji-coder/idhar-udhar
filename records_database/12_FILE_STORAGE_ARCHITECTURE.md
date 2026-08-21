# FILE STORAGE ARCHITECTURE

Do **not** store blobs in PostgreSQL.

**Object storage** (S3 / Cloudflare R2 / GCS) + `file_object` metadata in Postgres (`id`, `bucket`, `key`, `mime`, `size`, `sha256`, `owner_type`, `owner_id`, `visibility` private|public-cache, `created_at`).

## What to store

| File | App today | Production |
|---|---|---|
| Rider profile photo | Boolean only | private object |
| Aadhaar F/B, PAN, DL F/B, RC F/B, bank proof | localPath dummy | private; virus scan worker |
| Customer profile image | initials avatar | optional private |
| Parcel photo | none | optional |
| Proof of delivery | Admin `proofNote` text | private images + optional signature |
| Invoice PDF | generated in browser | private object + signed URL |
| Company logo | Admin `logoDataUrl` | public CDN asset |
| Vehicle / category images | Flutter assets | CDN public |
| Purchase invoice scans | none | private |

## Access

- Upload: `POST /v1/files/presign` → client PUT to S3 → `POST /v1/files/confirm`.  
- Download PII: short-lived signed GET after authz.  
- Public marketing assets: CDN.  
- Encryption at rest (bucket default).  
- Lifecycle: POD/invoices retain per legal (open: years); KYC retain while rider active + statutory.

## Rider camera

Keep using image_picker; upload replaces `localPath` as source of truth.
