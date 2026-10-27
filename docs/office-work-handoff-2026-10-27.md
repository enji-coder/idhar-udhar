# Office work handoff — 2026-10-27

Continue on `main` after `git pull`. This note records local files and read-only checks from the office session. It does not approve a migration apply, a Cashfree order, or a production change.

## Code and configuration

Commit `1b051bd` (`fix: guard staging migration target`) added `assertMigrationTarget()` in `backend/scripts/migrate.mjs` and its tests. The guard runs before `new pg.Client`. For `IU_DEPLOYMENT_TIER=staging` it requires the staging RDS host, database `idhar_udhar_staging`, and `CASHFREE_ENVIRONMENT=sandbox`, including when Cashfree is missing or empty. It rejects the production host, production tier, and production Cashfree.

The same commit added:

- `docs/ecs_staging_migrate.taskdef.template.json`
- `docs/ecs_staging_migrate.runtask.template.json`

The uncommitted task-definition change updates only the image tag to `staging-20261027-01`. The registry and repository stay `635738235470.dkr.ecr.ap-south-1.amazonaws.com/iu-staging-backend`. The template still sets `MIGRATE_DRY_RUN=1` and does not set `MIGRATE_CONFIRM`.

`docs/ecs_staging_migrate.runtask.template.json` remains guidance. `review.status` is `not-reviewed`. Its inner `runTask` object uses cluster `iu-staging-cluster`, Fargate, subnets `subnet-09ab7e7236a075ef6` and `subnet-07eac5da4b69b70d5`, security group `sg-003b05a0b649edf79`, and `assignPublicIp=DISABLED`. The documented command includes `--region ap-south-1`. Do not submit the whole guidance file to `run-task`.

## Deployment artifacts

These files contain no secret values. Password, JWT, OTP pepper, Cashfree, payout-key, and Google fields are Secrets Manager `valueFrom` ARNs.

- `api-task-definition-register.json` is a `RegisterTaskDefinition` document for family `idhar-udhar-staging-api`. Image tag `staging-20261027-01`. `NODE_ENV=production`, `IU_DEPLOYMENT_TIER=staging`, `CASHFREE_ENVIRONMENT=sandbox`, `PAYMENT_PROVIDER=cashfree`, `CASHFREE_API_VERSION=2025-01-01`, database `idhar_udhar_staging`, user `iu_staging_admin`, TLS certificate `/app/certs/rds-global-bundle.pem`, `LOCATION_STORE=memory`, `REDIS_ENABLED=false`, `ROUTING_PROVIDER=google`, port `3000`. CORS in this file is `http://localhost:5173,http://127.0.0.1:5173`. Bucket name `iu-staging-documents-635738235470`. No `OTP_DELIVERY_PROVIDER` and no MSG91 variables. Secret names: `DATABASE_PASSWORD`, `JWT_ACCESS_SECRET`, `REFRESH_TOKEN_PEPPER`, `OTP_HASH_PEPPER`, `CASHFREE_CLIENT_ID`, `CASHFREE_CLIENT_SECRET`, `PAYOUT_INSTRUMENT_KEY`, `GOOGLE_MAPS_API_KEY`.
- `migration-history-check-overrides.json` overrides the migrate container command with a read-only table inventory. The password is read from `DATABASE_PASSWORD` in the task environment.
- `migration-verify-overrides.json` overrides the command with a read-only `schema_migrations` count and first/last version. Same password source.
- `migration-apply-overrides.json` sets `MIGRATE_DRY_RUN=0` and `MIGRATE_CONFIRM=apply-missing`. This file can apply migrations. Do not run it without a separate approval.

`idhar_udhar/pubspec.lock` is an unrelated local modification. It downgrades transitive packages `matcher`, `meta`, `test_api`, and `vector_math`. It was left unstaged.

## AWS evidence from read-only checks

These checks did not register a task, run a migration, or create a payment.

- `iu-staging-api-service` on `iu-staging-cluster` was ACTIVE with desired 1 and running 1. Its task definition was `idhar-udhar-staging-api:2`. ECS Exec was disabled.
- Revision 2 had the same environment and secret names as the register document, including `NODE_ENV=production` and no MSG91 settings. This handoff does not claim the running image tag was re-read after the local tag edit.
- Log group `/ecs/iu-staging-backend` had API stream `api/api/a9f17eef987c4ae4abcc9af8062eff07` and several `migrate-dry-run` streams. A filter since 2026-10-26 found four Cashfree startup route logs. It found no `cashfree_order_created`, `cashfree_order_rejected`, `otp_delivery`, or `PAYMENT_GATEWAY` events. Absence of those logs is not a credential result.
- Image `staging-20261026-01` was built from commit `05bb129` and does not contain `assertMigrationTarget()`. Tag `staging-20261027-01` is the tag now written in the local templates. This session did not build or push an image, so the new tag's contents were not verified here.

## Cashfree sandbox audit

Configured, not verified. A sandbox order would be `POST https://sandbox.cashfree.com/pg/orders` from `CashfreePaymentService`, only after an authenticated rider calls `POST /v1/rider/wallet/recharge` with a positive amount and an idempotency key. Success proof is HTTP 201, `cashfree_environment=sandbox`, `cashfree_order_id`, `payment_transaction_id`, and log event `cashfree_order_created`. Do not record `payment_session_id`.

Blockers:

- Staging OTP delivery is unconfigured. Production mode discards the code and does not send SMS. Dev OTP capture and the dummy OTP are unavailable. A legitimate rider login cannot complete.
- Whether any rider profile exists in `idhar_udhar_staging` is unverified. Migrations do not seed riders.
- Whether an active `payment_method_policy_versions` row has `online_enabled=false` is unverified. No active row allows the online check to pass. An active row with online disabled rejects the recharge before Cashfree is called.

No Cashfree order was created. No wallet was credited.

## Next steps at home

1. `git pull` on `main`.
2. Leave `idhar_udhar/pubspec.lock` unstaged unless that downgrade is intentional.
3. Approve a private read-only query for a rider-profile count and the active payment-policy booleans. Do not open RDS or print phone numbers. ECS Exec is off, so this needs an approved one-off task or a separate exec enablement. `migration-history-check-overrides.json` and `migration-verify-overrides.json` are the prepared read-only overrides.
4. Do not run `migration-apply-overrides.json` until that read-only result is reviewed and apply is explicitly approved.
5. Staging SMS still needs `OTP_DELIVERY_PROVIDER=msg91` plus MSG91 settings before a real rider login can reach `POST /v1/rider/wallet/recharge`.
6. Do not create a sandbox order until the rider, the payment policy, and the login path are approved.

## Checks performed for this handoff

- JSON parse and field scan of the task definition, register document, and three override files. Sensitive fields were Secrets Manager references or environment variable names. No raw secret values were found or printed.
- `git diff --check` on the staged set.
- `node --test backend/scripts/migrate.test.mjs` was already run earlier today: 13 passed, 0 failed. It was not repeated for this documentation commit.
