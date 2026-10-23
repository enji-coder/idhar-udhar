# Cashfree staging preparation — Checkpoint 2

Placeholders only. Do **not** put real secrets in this file or in Git.

Owned by: SWIFTSEND INNOVATIONS PRIVATE LIMITED / IDHAR UDHAR.

**Status:** Codebase + documentation readiness for an isolated Sandbox staging stack.
**Not claimed:** AWS resources provisioned, staging deployed, or production isolation verified by an operator.

Related templates:

- `backend/.env.staging.example`
- `IDHAR_UDHAR_ADMIN/.env.staging.example`
- `docs/ecs_staging_backend.taskdef.template.json`
- `docs/cashfree_staging_app_commands.md`

---

## 1. Goal

Isolate Cashfree **Sandbox** traffic from production:

| Layer | Production (leave unchanged) | Staging (operator creates) |
|-------|------------------------------|----------------------------|
| API | Existing ECS service | New staging ECS service / task family |
| Database | Production RDS | Separate RDS instance **or** separate DB name on non-prod cluster |
| Secrets | `idhar-udhar/prod/...` (existing) | New secret e.g. `idhar-udhar/staging/backend` |
| Cashfree | Live credentials + live webhooks | Sandbox credentials + Sandbox webhooks only |
| Flutter | Production `API_BASE_URL` | `--dart-define=API_BASE_URL=https://<STAGING_API_HOST>` |
| Admin | Production `VITE_API_BASE_URL` | Staging `.env` / staging Netlify env |

**Pass condition (human):** test payments and wallet rows exist only in the staging database; production tables unchanged.

---

## 2. Backend environment variables (Cashfree Sandbox mode)

### Required for Sandbox payments

| Variable | Staging value |
|----------|----------------|
| `IU_DEPLOYMENT_TIER` | `staging` (enforces sandbox Cashfree hosts at startup) |
| `PAYMENT_PROVIDER` | `cashfree` |
| `CASHFREE_ENVIRONMENT` | `sandbox` |
| `CASHFREE_CLIENT_ID` | Sandbox PG client id |
| `CASHFREE_CLIENT_SECRET` | Sandbox PG secret (also used for PG webhook HMAC) |
| `CASHFREE_API_VERSION` | `2025-01-01` (or current Sandbox-supported version) |
| `CASHFREE_TIMEOUT_MS` | `10000` typical |

### Required platform (staging)

`DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_SSL` (+ CA as used today), `JWT_ACCESS_SECRET`, `REFRESH_TOKEN_PEPPER`, `OTP_HASH_PEPPER`, `JWT_ISSUER` (prefer `idhar-udhar-api-staging`), OTP/push/routing/redis/S3 as in `backend/.env.staging.example`.

### Optional Sandbox payouts

`CASHFREE_PAYOUT_CLIENT_ID`, `CASHFREE_PAYOUT_CLIENT_SECRET`, `CASHFREE_PAYOUT_API_VERSION`, `PAYOUT_RECONCILE_*`.

### Host selection (code)

`CASHFREE_ENVIRONMENT=sandbox` → `https://sandbox.cashfree.com/pg` (+ payout host).
`production` → `https://api.cashfree.com/pg`. No silent remapping.

### Anti-inheritance rules

1. Staging ECS must set `IU_DEPLOYMENT_TIER=staging`. Startup **refuses** `CASHFREE_ENVIRONMENT=production`.
2. Staging Secrets Manager name must not be the production secret ARN/name.
3. Never copy production `CASHFREE_*` into staging (or reverse).
4. Staging `DATABASE_HOST` / `DATABASE_NAME` must not be the production RDS endpoint/database.
5. Do not run migrate/dry-run against production while preparing staging.
6. Production task definitions must **omit** `IU_DEPLOYMENT_TIER=staging` (unset or `production`).

---

## 3. Staging database & networking (operator design)

### Database

1. Create a **staging-only** PostgreSQL (preferred: separate RDS instance).
2. Apply migrations only after Checkpoint 1 duplicate-prefix resolution (see §8).
3. Seed minimal catalog/auth data needed for booking + rider wallet tests (no production dumps with PII unless approved and scrubbed).
4. Confirm application users/roles cannot reach production RDS security groups.

### Networking (proposed)

- Private subnets for staging ECS tasks + staging RDS.
- Public ALB/API only for staging hostname `https://<STAGING_API_HOST>`.
- Security groups: staging tasks → staging RDS / staging Redis only.
- No security-group path from staging tasks to production RDS.
- Cashfree Sandbox webhook egress/ingress to staging ALB only.

### Secrets

- New secret: `idhar-udhar/staging/backend` (name illustrative).
- Keys mirror `backend/.env.staging.example` (Cashfree Sandbox + staging DB password + JWT peppers).
- IAM: staging task execution role may read **staging** secret only.

---

## 4. Sandbox webhook URLs

Register in **Cashfree Sandbox** dashboard (not production):

| Flow | URL |
|------|-----|
| Payments | `https://<STAGING_API_HOST>/v1/payments/cashfree/webhook` |
| Payouts (optional) | `https://<STAGING_API_HOST>/v1/payments/cashfree/payout-webhook` |

Requirements:

- Nest `rawBody: true` (already in `backend/src/main.ts`).
- HMAC headers `x-webhook-timestamp` + `x-webhook-signature`.
- PG webhooks signed with Sandbox `CASHFREE_CLIENT_SECRET`.
- Payout webhooks signed with Sandbox `CASHFREE_PAYOUT_CLIENT_SECRET`.

---

## 5. Flutter / Admin staging commands

See `docs/cashfree_staging_app_commands.md`. **Do not auto-build APKs.**

Critical: Rider without `API_BASE_URL` defaults to production API — always pass staging dart-define for Sandbox tests.

---

## 6. Sandbox verification scenarios

### Payment creation

1. Customer: create order → ONLINE plan → `POST /v1/orders/:id/payment/transactions` returns `payment_session_id` + `cashfree_environment=sandbox`.
2. Open Cashfree Sandbox checkout from the app.
3. Confirm Cashfree merchant dashboard shows Sandbox order (not live).

### Webhook signature

1. Deliver SUCCESS webhook to staging URL.
2. Invalid signature → rejected; order stays unpaid.
3. Valid signature → settles once.

### Payment status / verify

1. After checkout, customer flow calls verify; `transaction_status=PAID` only after server settlement.
2. Cancel/fail → PENDING/FAILED; UI must not show success from SDK alone.

### Duplicate events

1. Replay same webhook body/event → second apply ignored; wallet/finance side effects once.
2. Concurrent verify + webhook → CAS ensures single PAID transition.

### Rider wallet top-up

1. `POST /v1/rider/wallet/recharge` → Sandbox session.
2. Pay in Sandbox → webhook credits wallet and/or reduces COD Due once.
3. All-COD case: amount ≤ COD Due → COD ledger `source_txn_id=wallet-topup:{payment_transaction_id}`; no double decrease on replay.
4. App calls `POST /v1/rider/wallet/transactions/:id/verify` after SDK, then polls balance (webhook remains valid settle path).

### Admin ledger / reconciliation

1. Staging Admin → `GET /v1/admin/payments` shows staging rows only.
2. Match `payment_transactions` ↔ gateway attempts ↔ wallet/COD ledgers.
3. Outstanding receivable vs clearance payments reconcile on staging DB.

---

## 7. Manual production migration-history check (before resolving 0026/0027/0028)

**Do not rename/delete/edit** `0026_*`, `0027_*`, or `0028_*` SQL until this is done by a human on production (read-only).

Suggested read-only query (operator runs against production; agent must not):

```sql
SELECT version, filename, checksum, applied_at
FROM schema_migrations
WHERE version LIKE '0026%'
   OR version LIKE '0027%'
   OR version LIKE '0028%'
ORDER BY version, filename;
```

Record which stems exist:

| Prefix | Candidate files in repo | Action after verification |
|--------|-------------------------|---------------------------|
| 0026 | `...withdrawal.sql` vs `...withdrawals.sql` (different content) | Keep the applied stem; quarantine the other only after confirmation |
| 0027 | two files, **identical** checksum | One applied is enough; remove/ignore duplicate only after confirmation |
| 0028 | `payout_provider_references` vs `withdrawal_payout_refs` (different) | Keep applied; align the unused file only after confirmation |

The Node migrator refuses duplicate numeric prefixes before any DB connect. Staging migrate cannot proceed until the tree is unambiguous **after** production history is known.

Never run `MIGRATE_DRY_RUN=1` or apply against production for this preparation.

---

## 8. Operator AWS checklist (Checkpoint 2 → 3)

- [ ] Create staging RDS (or isolated DB) + security groups.
- [ ] Create staging Secrets Manager secret with Sandbox Cashfree + staging DB password.
- [ ] Create staging ECS task/service from `docs/ecs_staging_backend.taskdef.template.json` (filled privately).
- [ ] Set `IU_DEPLOYMENT_TIER=staging` and `CASHFREE_ENVIRONMENT=sandbox` on staging only.
- [ ] Point staging ALB DNS → staging service.
- [ ] Register Sandbox webhooks to staging URLs.
- [ ] Confirm production ECS/secrets/webhooks untouched.
- [ ] Resolve migration duplicates using §7, then migrate **staging DB only**.
- [ ] Run Sandbox scenarios in §6.
- [ ] Point staging Admin + Flutter dart-define at staging API only.

---

## 9. Rollback / non-goals

- Rollback staging = delete/disable staging service; production unaffected.
- Production activation remains Checkpoint 7 — out of scope here.
- Agents must not deploy, provision paid resources, or claim isolation without operator evidence.

---

## 10. Explicit non-actions

- No production RDS connections.
- No production migrate or dry-run.
- No live Cashfree charges from CI/agents.
- No APK release from this checkpoint.
- No edits to migration SQL `0026` / `0027` / `0028`.
