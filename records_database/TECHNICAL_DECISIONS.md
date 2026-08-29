# IDHAR UDHAR — TECHNICAL IMPLEMENTATION DECISIONS

**Type:** Implementation record (not a business-rules document)  
**Date:** 2026-08-24  
**Database:** local PostgreSQL `idhar_udhar`  
**Does not modify:** Master Architecture, Implementation Blueprint, Schema Specification, Schema Audit

These choices implement locked architecture. They do **not** change 85/15, GST, COD, payment splitting, identifiers, or resend formulas.

| # | Topic | Choice | Why |
|---|---|---|---|
| 1 | Money | `NUMERIC(12,2)` everywhere (domain `money_inr`) | Exact INR rupees/paise. No FLOAT/DOUBLE. Master §43 allows this or integer paise; one type is used uniformly. |
| 2 | Percents | `NUMERIC(5,2)` domain `percent_100` (0–100) | Matches Blueprint `percent`. |
| 3 | UUID PK default | `uuid_generate_v7()` (SQL helper, `pgcrypto`) | Architecture wants time-sortable UUIDs. App may still supply UUID v7. Type remains UUID. |
| 4 | Timestamps | `TIMESTAMPTZ` + `now()` | Master requires timestamptz. |
| 5 | Status lists | `TEXT` + `CHECK` (not `ENUM`) | Spec: adding a locked value later must not require `ALTER TYPE`. |
| 6 | Wallet ↔ COD twin FKs | `DEFERRABLE INITIALLY DEFERRED` both directions | Settlement posts both rows in one transaction. No CASCADE. |
| 7 | OTP identity FK | `ON DELETE RESTRICT` | Identities are not hard-deleted. |
| 8 | Vehicle unassign | `ON DELETE SET NULL` on `vehicles.rider_profile_id` | Architecture allows unassigned vehicles. |
| 9 | GPS samples table | **Omitted from V1** | Audit: not required; Redis is hot GPS; no retain policy. |
| 10 | Customer wallet tables | Created, **isolated**, not wired to booking/payments | Architecture READY. No auto-debit. No FK from orders. |
| 11 | Case A versions | CHECK: Case A requires fare + payment-settings version FKs | Audit HIGH #4. Traceable 85/15 at resend time. Formulas unchanged. |
| 12 | Case A/B row shape | Both `parent_order_id` and `resend_snapshots.child_order_id` exist | Master TECHNICAL DESIGN OPTION. Runtime shape is not a new fee. |
| 13 | Max 3 drops | Deferred constraint trigger: 1 PICKUP + 1..3 DROP | Locked rule; enforcement is technical. |
| 14 | Plan vs responsibility | Deferred constraint trigger | Locked cross-table rule. |
| 15 | Invoice header | Full Blueprint B.44 columns; lines are display copies | Header is money authority. No GSTIN/SAC invented. Unique `order_id` for V1 retry. |
| 16 | Ratings | Typed from/to profile FKs by direction | Audit HIGH #15. Rider→customer allowed as a row; product edit rules unchanged. |
| 17 | Admin password | `admin_profiles.password_hash` | Spec pick so OTP identities have no password column. |
| 18 | Licence | `licence_masked` + `licence_encrypted_or_token` | Master §32.3 national IDs at rest. |
| 19 | Cancel snapshot uniqueness | Partial unique `(order_id) WHERE allowed = TRUE` | Successful cancel once; rejected attempts may be stored. |
| 20 | Payment txn idempotency | Unique `(order_id, idempotency_key)` plus `idempotency_keys` | One uniqueness home on the txn row; global table remains for other scopes. No TTL. |
| 21 | Immutability | Triggers forbid UPDATE/DELETE on financial/history tables | Table owner cannot REVOKE from self; triggers are the DB protection. |
| 22 | Display ID allocator | Per-city row `UPDATE … last_seq + 1` (atomic upsert) | Not a global sequence bottleneck. Format `IU-{CITY}-{10 digits}` locked. |
| 23 | Notification extra tables | `notification_preferences`, `notification_deliveries` | Database support for future worker/push. No provider integration. No chat. |
| 24 | Extensions | `pgcrypto` only | `gen_random_bytes` for UUID v7. |
| 25 | Rounding column | `NUMERIC(12,2)` with no sign CHECK | Fare engine stores already-rounded facts; round-down may be negative paise. |
| 26 | Bank `is_current` default | `FALSE` | Safer with partial unique one-current. |
| 27 | Rider soft-delete | `deactivated_at` nullable | Aligns with master soft-delete of masters. |
| 28 | Config JSONB vs child rates | Child rate rows | Spec already chose child rows for CHECKs/FKs. |

**NEEDS BUSINESS DECISION (unchanged, not invented):**

- OTP length / SMS provider / expiry minutes / lockout
- Session TTL and JWT vs cookie
- Invoice legal series format (GSTIN/SAC/e-invoice)
- Launch cash-only vs online-on
- Capture-at-booking vs capture-at-delivery
- Case A/B **runtime** storage shape (child order vs related record)
- Close failed delivery without resend
- Customer wallet auto-debit / min-max / KYC
- GPS breadcrumb retention (table not created)
- Rider→customer rating edit / public comments
- Manual Admin second live trip
- Staff RBAC cells beyond Master §8.2 minimums
