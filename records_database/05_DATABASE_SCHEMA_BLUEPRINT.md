# DATABASE SCHEMA BLUEPRINT

**Status:** Blueprint only. No tables created. No migrations.

**Primary store:** PostgreSQL 16+ (OLTP + reporting source).  
**Cache / ephemeral:** Redis.  
**Files:** Object storage (S3-compatible).  
**IDs:** UUID v7 (time-sortable) for new rows. Display IDs (`IU-AMD-#####`) are unique secondary keys.

Conventions: `created_at`, `updated_at` timestamptz; money `numeric(12,2)`; percents `numeric(5,2)`; soft delete `deleted_at` where noted; PII columns marked SENSITIVE.

---

## 1. identity & auth

### customer
PK `id` UUID. Unique `phone` E.164. `name` varchar(80) not null after setup. `email` varchar(120) nullable unique where not null. `status` (active/inactive). `referral_code` unique nullable. SENSITIVE: phone, email, name. Index: phone, email.

### rider
PK `id`. Unique `phone`. `name`, `email`, `date_of_birth` date, `language`, `photo_file_id`, `rating_avg` numeric(3,2), `status` (pending_verification, correction, approved, rejected, suspended, active, offline, busy). `home_zone_id` FK zone. SENSITIVE: phone, email, dob.

### rider_driver
PK `id`. FK `rider_id`. `full_name`, `mobile`, `date_of_birth`, `license_number` unique. Use when owner ≠ driver; else 1:1 with rider.

### admin_user
PK `id`. Unique `email`. `name`, `role`, `status`, `finance_access` bool, `payout_approve` bool. Modules via `admin_user_module(admin_user_id, module_key)`. Password hash **server-only** (argon2id). Never in apps.

### otp_challenge
PK `id`. `channel` sms. `phone`. `code_hash` (not plaintext). `expires_at`. `attempts`. `consumed_at`. `actor_type` customer|rider|admin. SENSITIVE.

### session_token
PK `id`. `actor_type`, `actor_id`. `refresh_token_hash`. `expires_at`. `revoked_at`. `device_meta` jsonb. SENSITIVE hashes.

---

## 2. geography & catalog

### zone
PK `id`. `name` unique. `area_text`. `status`. Optional `boundary` geography(Polygon) later.

### customer_address
PK `id`. FK `customer_id`. `label` enum home|office|friend|other. `line1` not null. `landmark`. `city`. `lat`/`lng` numeric nullable. `is_default` bool. Soft delete. Index `(customer_id, deleted_at)`.

### vehicle_category
PK `id` UUID (**stable; never join by name**). Unique `name`. `status` active|inactive. `available` bool (computed or admin). `sort_order`. `capacity_kg` int nullable. `max_dimension_cm` int nullable. `image_file_id`. Soft deactivate preferred over delete.

### parcel_category / parcel_size
PK `id`. `code` unique (`c_docs`). `label`. `sort_order`. `status`.

### vehicle (fleet and/or rider-owned)
PK `id`. FK `vehicle_category_id` not null. FK `rider_id` nullable. `registration_number` unique. `brand`, `model`, `variant`, `color`, `year`. `two_wheeler_subtype` bike|scooter nullable. `status` active|inactive|maintenance|available|busy. `rc_expiry`, `insurance_expiry`. Index category, rider, registration.

---

## 3. orders

### order
PK `id`. Unique `display_id`. FK `customer_id` not null. FK `rider_id` nullable. FK `vehicle_category_id` not null. FK `vehicle_id` nullable. `status` (see 14_DATA_FLOW). `service_family` two_wheeler|three_wheeler|truck nullable. `scheduled_at` timestamptz nullable. `fragile` bool. `cod` bool. `instructions` varchar(500). `distance_km` numeric. `eta_seconds` int. `cancelled_by` customer|rider|admin. `cancel_reason`. `searching_started_at`. Indexes: `(customer_id, created_at desc)`, `(rider_id, status, created_at desc)`, `(status, created_at)`, `display_id`, `(vehicle_category_id)`. Soft cancel via status not delete.

### order_stop
PK `id`. FK `order_id`. `kind` pickup|drop. `address_snapshot` jsonb not null (label, line, city, lat, lng, landmark). `address_id` FK nullable.

### order_parcel
PK `id`. FK `order_id` unique. FK `parcel_category_id`. FK `parcel_size_id`. `weight_kg` numeric(8,3). `quantity` int default 1.

### order_vehicle_snapshot / order_rider_snapshot
JSONB or dedicated columns: category name, vehicle number, rider name, masked phones as shown to counterpart. Frozen at assign/complete.

### order_status_event
PK `id`. FK `order_id`. `from_status`. `to_status`. `actor_type`. `actor_id`. `at`. Index `(order_id, at)`.

### order_offer
PK `id`. FK `order_id`. FK `rider_id`. `status` pending|accepted|rejected|expired. `expires_at`. Unique partial index one pending offer per rider. Unique: one accepted offer per order.

---

## 4. money

### payment_settings_version
PK `id`. `rider_share_percent` numeric(5,2) not null. `company_commission_percent` numeric(5,2) not null. CHECK sum = 100. `operational_cost_percent` numeric(5,2) not null (of commission). `effective_from` timestamptz not null. `effective_to` timestamptz nullable. `created_by` FK admin_user. `created_at`. `supersedes_id` FK self nullable. Never update in place for historical rates — insert new version.

### fare_quote
PK `id`. FK `order_id` or draft token. Lines: base, distance, vehicle_surcharge, platform, tax, packaging, discount. `total`. `quoted_at`. `expires_at`.

### order_fare_snapshot
Copy of applied quote at confirm. Immutable.

### order_finance_snapshot
PK `id`. FK `order_id` unique. FK `payment_settings_version_id`. Frozen: `ride_amount`, `rider_amount`, `rider_percent`, `company_commission`, `company_commission_percent`, `operational_cost`, `operational_cost_percent`, `actual_profit`, `currency` INR. Written at **financial freeze** (delivered or terminal paid cancel policy). Immutable.

### payment
PK `id`. FK `order_id` nullable. FK `wallet_id` nullable. `amount`. `method` upi|cash|card|net_banking|wallet. `direction` charge|refund. `status` pending|paid|failed|refunded. Unique `provider_txn_id` nullable. `idempotency_key` unique. Index order_id, status, created_at.

### wallet
PK `id`. `owner_type` customer|rider. `owner_id`. Unique `(owner_type, owner_id)`. `available_balance`, `pending_balance` numeric. Version `row_version` for optimistic lock.

### wallet_transaction
PK `id`. FK `wallet_id`. `type` credit|debit|refund|adjustment|payout|penalty|incentive. `amount` signed or type+absolute. `balance_after`. FK `order_id` nullable. FK `payment_id` nullable. `idempotency_key` unique. Index `(wallet_id, created_at desc)`.

### payout
PK `id`. FK `rider_id`. `amount`. `status` pending|approved|paid|rejected. `method` upi|bank. `period_start/end`. `approved_by`. `paid_at`.

### invoice
PK `id`. Unique `invoice_number`. FK `order_id`. FK `customer_id`. `status` draft|issued|cancelled. Amounts: subtotal, packaging, tax_rate, tax, discount, total. `pdf_file_id`. `emailed_to`. `issued_at`. Company legal snapshot jsonb.

### purchase_invoice
Ops AP: vendor, item_type, amounts, payment_status. Not customer-facing.

---

## 5. KYC, comms, support

### rider_document
PK `id`. FK `rider_id`. `kind`. `status`. `file_id`. `reviewed_by`. `reviewed_at`. Expiry dates where applicable.

### rider_bank_account / rider_upi
Encrypted/tokenized account number, IFSC, UPI. `verified`. SENSITIVE. Access finance/ops roles only.

### notification
PK `id`. `recipient_type` + `recipient_id`. `type`. `title`. `body`. `data` jsonb (order_id, deep_link). `read_at` nullable. `created_at`. Index `(recipient_type, recipient_id, created_at desc)` INCLUDE read_at. **Cursor pagination.** Do not select unbounded.

### announcement
PK `id`. `audience`. `status`. `title`. `body`. `published_at`.

### support_ticket / support_message

### coupon / coupon_redemption

### rating
FK `order_id` unique per direction. `stars` 1–5. `comment`. `from_actor`.

### proof_of_delivery
FK `order_id`. `file_id`s. `otp` hash optional. `captured_at`. `lat/lng`.

### audit_log
`actor_id`, `role`, `action`, `entity`, `entity_id`, `before` jsonb, `after` jsonb, `at`, `ip`, `user_agent`. Append-only. Partition by month later.

### daily_order_stats (reporting)
PK `(stat_date, zone_id, vehicle_category_id)` or city grain. Counts: created, delivered, cancelled, failed. Sums: ride_amount, rider_amount, commission, opex, profit. **Updated by worker, not Admin full-table scan.**

---

## Indexes (Day 1)

- All FKs  
- order display_id unique  
- order (status) where not terminal  
- wallet_transaction (wallet_id, created_at desc)  
- notification unread partial index `WHERE read_at IS NULL`  
- vehicle_category name unique  
- payment provider_txn_id unique where not null  

## Partition later (not Day 1)

order_status_event, audit_log, rider_location_history, notification (by month), wallet_transaction if > tens of millions.
