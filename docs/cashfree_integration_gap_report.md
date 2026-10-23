# Cashfree integration — gap report

**Project:** IDHAR UDHAR (`enji-coder/idhar-udhar`)
**Date:** 2026-10-23
**Scope:** Customer Flutter, Rider Flutter, NestJS backend, Admin portal, PostgreSQL, Cashfree PG + Payouts

**Method:** Source-code inspection + existing unit/e2e test inventory only.
**Not done:** AWS/DB connections, live or Sandbox charges, production `schema_migrations` read, deploys, APK builds.

Verification legend used below:

| Label | Meaning |
|-------|---------|
| **Source** | Present in repository code |
| **Unit** | Covered by automated unit/spec tests (mocked; not a real gateway) |
| **Sandbox** | Requires a real Cashfree Sandbox transaction + staging/isolated API — **not verified in this audit** |

---

## 1. Implemented features

| Feature | Paths (primary) | Source | Unit | Sandbox |
|---------|-----------------|--------|------|---------|
| ONLINE charge create + payment session | `backend/src/payments/payments.service.ts` (`createTransaction` / `beginOnlineCharge`), `cashfree-payment.service.ts` | Yes | Partial (`payments.service.spec.ts`, e2e) | No |
| Rider wallet top-up session | `beginRiderWalletTopUp`, `rider-wallet.controller.ts` `POST wallet/recharge` | Yes | Partial | No |
| Customer order verify (retrieve CF + amount match + settle) | `verifyOnlinePayment`, `order-payments.controller.ts` `…/verify` | Yes | Yes (`verify-online-payment.spec.ts`) | No |
| PG webhook HMAC on **raw body** | `main.ts` `rawBody: true`, `cashfree-signature.ts`, `cashfree-webhook.controller.ts` | Yes | Yes (`cashfree-webhook.parse.spec.ts`, controller/service specs) | No |
| Webhook event-id idempotency + CAS PAID | `cashfree-webhook.service.ts`, `payment_webhook_events` | Yes | Yes | No |
| Refund create (provider) + refund webhook apply | `refundCapturedOnline`, `applyRefund` | Yes | Partial | No |
| Wallet top-up credit on verified PAID | `WalletCodService.applyVerifiedWalletTopUp` via webhook (+ settle helper) | Yes | Yes (`wallet-cod.wallet-topup.spec.ts`, webhook specs) | No |
| Payout webhook separate secret | `cashfree-payout-webhook.controller.ts` | Yes | Yes | No |
| PG vs payout credential separation | `configuration.ts`, `cashfree-payment.service.ts` | Yes | Yes (`configuration.payment.spec.ts`) | No |
| Staging refuses live Cashfree hosts | `IU_DEPLOYMENT_TIER=staging` guard in `configuration.ts` | Yes | Yes | N/A |
| Secret/session redaction in logs | `app-logger.ts` | Yes | Yes | N/A |
| Customer trip: SDK then **server verify** | `booking_api.dart` calls `verifyOnlineTripTransaction` | Yes | Backend Yes (`verify-online-payment.spec.ts`). Flutter caller is source-only | No |
| Customer receivable: SDK then **server verify** | `waiting_charge_prompt.dart` calls `verifyOnlineTripTransaction`, then `getById` | Yes | No dedicated verify test (session-gating test only) | No |
| Rider wallet verify (order-less `WALLET_TOPUP`) | `payments.service.ts` `verifyRiderWalletTopUp`; `rider-wallet.controller.ts` `POST wallet/transactions/:transactionId/verify` | Yes | Yes (`verify-online-payment.spec.ts`) | No |
| Rider top-up: SDK then **server verify**, then short balance poll | `wallet_topup_checkout.dart` `verifyRiderWalletTopUpAfterCheckout`, called from `rider_wallet_screen.dart` and `rider_dashboard_screen.dart` | Yes | Parser only (`receivable_clearance_test.dart`). Screen call sites are not unit-tested | No |
| Admin payments / wallet / payouts read | `Payments.jsx`, `Wallet.jsx`, `Payouts.jsx` + `adminApi.js` | Yes | Thin (permissions) | No |
| Admin refund dialogs | `Payments.jsx`, `Orders.jsx` | Yes — dialogs open and do **not** call the refund API | No | No |
| Staging templates / docs | `docs/cashfree_staging_preparation.md`, `.env.staging.example`, ECS template | Yes | `staging-env.example.spec.ts` | No |

**Safety note (Source):** Flutter SDK success callbacks do **not** mark PAID / credit wallet. Settlement requires webhook and/or backend verify with Cashfree retrieve + INR amount match.

---

## 2. Missing features / confirmed gaps

| Gap | Severity | Safe to fix locally? | Notes |
|-----|----------|----------------------|-------|
| Admin refund actions unwired on purpose | Medium (ops) | **No** — leave unwired | `Payments.jsx` and `Orders.jsx` open dialogs that do not call the refund API. `Payments.jsx` copy says the dialog is not wired and that order ONLINE refunds are sandbox-gated. `Orders.jsx` still says refunds are not on the server and only shows a toast. Backend `refundCapturedOnline` exists and is sandbox-gated. Do **not** wire or enable Admin refunds without explicit approval |
| Staging AWS / isolated DB / Sandbox webhooks | Blocker for CP3+ | **No** | Needs explicit infra authorization |
| Unambiguous migration tree `0026`/`0027`/`0028` | Blocker for any migrate | **No** | Pending DBA-approved production read-only `schema_migrations` history. Not queried in this correction |
| Real Cashfree Sandbox end-to-end | Blocker for claiming payments work | **No** | Source and unit tests do not substitute for a Sandbox charge, webhook, and verify |

Removed from this table because source now contains them (Sandbox still **not** verified): rider `POST …/wallet/transactions/:transactionId/verify`, rider Flutter verify-after-SDK, and customer receivable verify-after-SDK.

---

## 3. Relevant file paths

### Backend
- `backend/src/payments/payments.service.ts` — create, verify, refund, wallet top-up begin, settle helper
- `backend/src/payments/cashfree-payment.service.ts` — CF HTTP (orders, refunds, payouts)
- `backend/src/payments/cashfree-webhook*.ts`, `cashfree-signature.ts`, `cashfree-environment.ts`
- `backend/src/payments/order-payments.controller.ts`
- `backend/src/wallet-cod/rider-wallet.controller.ts`, `wallet-cod.service.ts`
- `backend/src/config/configuration.ts`
- `backend/scripts/migrate.mjs` — duplicate numeric prefix refusal

### Flutter
- `idhar_udhar/lib/customer/core/state/booking_api.dart` — trip verify-after-SDK
- `idhar_udhar/lib/customer/features/booking/presentation/widgets/waiting_charge_prompt.dart` — receivable verify-after-SDK, then `getById`
- `idhar_udhar/lib/customer/features/booking/presentation/waiting_charge_checkout.dart`
- `idhar_udhar/lib/rider/features/wallet/wallet_topup_checkout.dart` — `verifyRiderWalletTopUpAfterCheckout`
- `idhar_udhar/lib/rider/screens/wallet/rider_wallet_screen.dart` — calls that helper, then a short balance poll
- `idhar_udhar/lib/rider/screens/dashboard/rider_dashboard_screen.dart` — same helper, then a short balance poll
- `idhar_udhar/lib/shared/api/orders_api.dart` (`verifyOnlineTripTransaction`), `wallet_api.dart` (`verifyTopUp`)

### Admin
- `IDHAR_UDHAR_ADMIN/src/pages/Payments.jsx`, `Orders.jsx` — refund dialogs present, intentionally unwired
- `IDHAR_UDHAR_ADMIN/src/pages/Wallet.jsx`, `Payouts.jsx`
- `IDHAR_UDHAR_ADMIN/src/api/adminApi.js`

### Migrations / access docs
- `records_database/migrations/0026_*`, `0027_*`, `0028_*` (duplicate prefixes)
- `docs/request-production-readonly-db-access.md`
- `docs/production-migration-history-verification.md`
- `docs/cashfree_staging_preparation.md`

---

## 4. Test coverage (inventory)

| Suite | What it proves | Does **not** prove |
|-------|----------------|--------------------|
| `verify-online-payment.spec.ts` | Outcome map; settle BOOKING / RECEIVABLE / WALLET_TOPUP; `verifyRiderWalletTopUp` credits an order-less top-up once, rejects amount mismatch, and hides non-wallet charges | Real CF HTTP |
| `cashfree-webhook*.spec.ts` | HMAC/raw parse; duplicate events; wallet/receivable apply | Live webhook delivery |
| `cashfree-payment.service.spec.ts` | Redaction; payout vs PG headers | Live API |
| `configuration.payment.spec.ts` | Staging sandbox guard; credential split | Deployed env |
| `wallet-cod.wallet-topup.spec.ts` | Ledger/COD idempotency | Gateway |
| `test/payments.e2e-spec.ts` / `wallet-cod.e2e-spec.ts` | Local DB flows (when available) | Sandbox |
| Flutter `receivable_clearance_test.dart`, trip payment tests | Clearance session can open checkout; wallet verify JSON parses `transaction_status` | That wallet/dashboard or receivable screens call verify; SDK/Sandbox |
| Admin `permissions.spec.js` | Route access | Payment correctness |

**Unit coverage still absent:** Flutter call sites for rider verify and receivable verify. Backend rider verify is covered. No suite here is a real Cashfree Sandbox transaction.

---

## 5. Security findings

| Finding | Risk | Status |
|---------|------|--------|
| Marking PAID from Flutter SDK alone | Critical if present | **Not found** (Source) |
| Webhook without raw-body HMAC | Critical | Mitigated (Source + Unit) |
| Double wallet credit on retry/duplicate | High | Mitigated via event uniqueness + CAS + ledger idempotency (Unit) |
| Mixing PG and payout secrets | High | Separated (Source + Unit) |
| Staging using production Cashfree hosts | High | Refused when `IU_DEPLOYMENT_TIER=staging` (Unit) |
| Logging secrets / session ids | High | Redaction present (Unit) |
| Using app/ECS Exec for ad-hoc prod DB queries | High (process) | Documented as forbidden |
| Applying duplicate-prefix migrations / wrong `0028` stem | High for schema | **Blocked** until prod history verified |

No production credentials were read for this report.

---

## 6. Migration blockers

Duplicate numeric prefixes (migrator refuses before DB connect):

| Prefix | Candidates | Content |
|--------|------------|---------|
| 0026 | `…withdrawal.sql` vs `…withdrawals.sql` | Different |
| 0027 | `wallet_idempotency_scopes` vs `idempotency_wallet_scopes` | Identical checksum |
| 0028 | `payout_provider_references` vs `withdrawal_payout_refs` | Different; latter indexes `provider_transfer_id` without adding it |

**Rule:** Do not rename/delete/edit these until an approved read-only `schema_migrations` SELECT is completed (`docs/request-production-readonly-db-access.md`).

---

## 7. Sandbox verification requirements (human / staging)

When isolated staging exists (explicit approval):

1. Customer ONLINE trip: create → Sandbox pay → webhook **and** verify → `PAID` once.
2. Receivable clearance: same, outstanding clears only after server settle.
3. Rider wallet top-up: recharge → Sandbox pay → verify **and/or** webhook → wallet/COD once; replay no double credit.
4. Invalid HMAC rejected; amount mismatch never PAID.
5. Confirm rows only in staging DB; production untouched.
6. Optional: Sandbox refund path (not live).

Until then, **do not claim Sandbox payment testing passed**.

---

## 8. Prioritized next steps

These are the remaining blockers. Rider wallet verify, rider Flutter verify-after-SDK, and customer receivable verify-after-SDK are already in source. Do not treat them as open implementation work. None of them has been proven with a real Sandbox payment.

1. **DBA/security:** Approve and run the production read-only `schema_migrations` query for `0026`/`0027`/`0028` (`docs/request-production-readonly-db-access.md`). This correction did not run that query.
2. **Infra approval:** Provision staging AWS, an isolated database, and secrets; register Cashfree **Sandbox** webhooks.
3. **Sandbox (human, staging only):** Run the scenarios in §7. Do not claim Sandbox passed until that happens.
4. **After production history is returned:** Resolve the twin migration files under approval, then migrate **staging only**. Checkpoint 3+ stays blocked until then.
5. **Admin refunds:** Leave `Payments.jsx` and `Orders.jsx` unwired. Do not enable refunds in this workstream. Wiring them later needs a separate explicit approval, and backend refunds remain sandbox-gated.

---

## 8b. Remediation applied in this workstream (local only)

| Change | Status |
|--------|--------|
| `POST /v1/rider/wallet/transactions/:transactionId/verify` + settle without order | Implemented + unit tests |
| Rider Flutter verify-after-SDK (wallet + dashboard) | Implemented |
| Customer receivable verify-after-SDK | Implemented |
| Admin refund dialogs left unwired | `Payments.jsx` copy says the dialog is not wired. `Orders.jsx` still uses the older “not on the server” toast. Neither calls the refund API. Not enabled |
| Twin migrations / staging AWS / Sandbox E2E | **Not** changed |

---

## 9. Distinction summary

| Claim | This audit |
|-------|------------|
| Code implements create / order verify / rider wallet verify / receivable and rider Flutter verify-after-SDK / webhook / wallet credit / payout secret split | **Source verified** |
| Order verify and `verifyRiderWalletTopUp` settle/idempotency paths | **Unit verified** (mocked gateway) |
| Flutter screens actually calling verify | **Source only** — not unit-tested at the call site |
| Real Cashfree Sandbox payment end-to-end works | **Not verified** |
| Production migration history for twins `0026`/`0027`/`0028` | **Not verified** (DBA approval pending) |
| Admin refund actions | **Present and unwired** — not enabled |
