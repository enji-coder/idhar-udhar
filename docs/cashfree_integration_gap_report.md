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
| Customer trip: SDK then **server verify** | `booking_api.dart`, `waiting_charge_checkout.dart` | Yes | Flutter unit (status gating) | No |
| Rider top-up: SDK then **balance poll only** | `wallet_topup_checkout.dart`, wallet/dashboard screens | Yes | Thin | No |
| Admin payments / wallet / payouts read | `Payments.jsx`, `Wallet.jsx`, `Payouts.jsx` + `adminApi.js` | Yes | Thin (permissions) | No |
| Staging templates / docs | `docs/cashfree_staging_preparation.md`, `.env.staging.example`, ECS template | Yes | `staging-env.example.spec.ts` | No |

**Safety note (Source):** Flutter SDK success callbacks do **not** mark PAID / credit wallet. Settlement requires webhook and/or backend verify with Cashfree retrieve + INR amount match.

---

## 2. Missing features / confirmed gaps

| Gap | Severity | Safe to fix locally? | Notes |
|-----|----------|----------------------|-------|
| No `POST /v1/rider/wallet/…/verify` for order-less `WALLET_TOPUP` | **High** (UX + delayed webhook) | **Yes** | Settle helper already credits top-ups; order verify cannot own null-`order_id` charges |
| Customer receivable: no verify after SDK (only `getById`) | **High** (same class as trip) | **Yes** | Reuse existing order verify API |
| Admin Refund button unwired; copy says “not on server yet” | Medium (ops) | Message only without approval | Backend refund exists but is **sandbox-gated** (`Online refunds require Cashfree sandbox`). Do **not** wire Admin → live refunds without explicit approval |
| Dedicated rider Flutter verify client | High (pairs with API) | **Yes** | Call verify then keep short poll |
| Staging AWS / isolated DB / Sandbox webhooks | Blocker for CP3+ | **No** | Needs explicit infra authorization |
| Unambiguous migration tree `0026`/`0027`/`0028` | Blocker for any migrate | **No** | Pending approved production RO history |

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
- `idhar_udhar/lib/customer/features/booking/presentation/widgets/waiting_charge_prompt.dart` — receivable (gap)
- `idhar_udhar/lib/customer/features/booking/presentation/waiting_charge_checkout.dart`
- `idhar_udhar/lib/rider/features/wallet/wallet_topup_checkout.dart`
- `idhar_udhar/lib/rider/screens/wallet/rider_wallet_screen.dart`
- `idhar_udhar/lib/rider/screens/dashboard/rider_dashboard_screen.dart`
- `idhar_udhar/lib/shared/api/orders_api.dart`, `wallet_api.dart`

### Admin
- `IDHAR_UDHAR_ADMIN/src/pages/Payments.jsx`, `Wallet.jsx`, `Payouts.jsx`
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
| `verify-online-payment.spec.ts` | Outcome map; settle BOOKING / RECEIVABLE / WALLET_TOPUP; amount reject; no double credit | Real CF HTTP |
| `cashfree-webhook*.spec.ts` | HMAC/raw parse; duplicate events; wallet/receivable apply | Live webhook delivery |
| `cashfree-payment.service.spec.ts` | Redaction; payout vs PG headers | Live API |
| `configuration.payment.spec.ts` | Staging sandbox guard; credential split | Deployed env |
| `wallet-cod.wallet-topup.spec.ts` | Ledger/COD idempotency | Gateway |
| `test/payments.e2e-spec.ts` / `wallet-cod.e2e-spec.ts` | Local DB flows (when available) | Sandbox |
| Flutter `receivable_clearance_test.dart`, trip payment tests | Session gates / paid-from-server | SDK/Sandbox |
| Admin `permissions.spec.js` | Route access | Payment correctness |

**Missing unit coverage before this workstream’s fixes:** rider HTTP verify endpoint; receivable UI calling verify (behavior change needs a focused test where practical).

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

1. **DBA/security:** Approve and run production RO `schema_migrations` query for `0026`/`0027`/`0028` (external blocker).
2. **Engineering (local, this workstream):** Add rider wallet verify API + Flutter call; receivable verify-after-SDK; clarify Admin refund copy; unit tests.
3. **Your approval:** Provision staging AWS/DB/secrets; register Cashfree **Sandbox** webhooks; run Sandbox scenarios.
4. **After history:** Resolve twin migrations; migrate **staging only**; Checkpoint 3+.
5. **Explicit approval:** Wire Admin refund UI (if desired) knowing refunds are currently sandbox-gated in backend.

---

## 8b. Remediation applied in this workstream (local only)

| Change | Status |
|--------|--------|
| `POST /v1/rider/wallet/transactions/:transactionId/verify` + settle without order | Implemented + unit tests |
| Rider Flutter verify-after-SDK (wallet + dashboard) | Implemented |
| Customer receivable verify-after-SDK | Implemented |
| Admin refund modal copy corrected (still unwired) | Implemented |
| Twin migrations / staging AWS / Sandbox E2E | **Not** changed |

---

## 9. Distinction summary

| Claim | This audit |
|-------|------------|
| Code implements create / verify / webhook / wallet credit / payout secret split | **Source verified** |
| Critical settle/idempotency paths have unit tests | **Unit verified** |
| Real Cashfree Sandbox payment end-to-end works | **Not verified** |
| Production migration history for twins | **Not verified** (approval pending) |
