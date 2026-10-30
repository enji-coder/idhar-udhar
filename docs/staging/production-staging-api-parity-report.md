# Production and staging API parity

Date: 2026-10-30. Scope: repository inspection and local unit tests. No database write, AWS change, deployment, OTP, or Cashfree call was made.

## 1. Production reference

There is one NestJS API. `backend/src/app.module.ts` loads audit, auth, catalog, files, health, location, notifications, orders, payments, profiles, routing, reports, and wallet-cod. The global prefix is `/v1`.

The newest committed production task-definition snapshot is `idhar_udhar/task-definition-29.json`:

- Family `idhar-udhar-backend`
- Image `idhar-udhar-backend:dc7ba50`
- Commit `dc7ba50` (2026-10-13, `merge: integrate rider delivery fixes into main`)
- Database name `idhar_udhar` on the production RDS host
- `NODE_ENV=production`
- `IU_DEPLOYMENT_TIER` is not set
- `PAYMENT_PROVIDER=cashfree`
- `CASHFREE_ENVIRONMENT=production`
- `OTP_DELIVERY_PROVIDER=msg91`
- `PUSH_PROVIDER=fcm`
- `REDIS_ENABLED=true`, `LOCATION_STORE=redis`
- `NOTIFICATION_WORKER_ENABLED=true`
- `PAYOUT_RECONCILE_WORKER_ENABLED=true`
- CORS `https://admin.idharudhar.co.in`

`ecs-task-definition.json` is an older snapshot, image `idhar-udhar-backend:639f481` (2026-10-07). It has no `PAYMENT_PROVIDER` and no Cashfree variables. It is not the latest production file in this repository.

The running production task was not described. This report does not treat either file as proof of what ECS is serving today.

## 2. Staging reference

Staging uses the same `backend/src` tree. It is not a second API.

Previously verified, read-only, on 2026-10-30: account `635738235470`, cluster `iu-staging-cluster`, service `iu-staging-api-service`, task definition `idhar-udhar-staging-api:3`, image `iu-staging-backend:staging-20261027-01`. `GET /health` returned database name `idhar_udhar_staging`. Non-secret environment: `IU_DEPLOYMENT_TIER=staging`, `NODE_ENV=production`, `CASHFREE_ENVIRONMENT=sandbox`, `PAYMENT_PROVIDER=cashfree`, `OTP_DELIVERY_PROVIDER=msg91`.

The checked-in staging document is `ecs-staging-task-definition-msg91.json`. It matches that revision's image and those variables. `REDIS_ENABLED=false`, `LOCATION_STORE=memory`. CORS is `http://localhost:5173,http://127.0.0.1:5173`.

Commit `05bb129` (2026-10-26, `feat: secure rider Cashfree payout withdrawals`) is the last staging image whose source was verified, and that image tag was `staging-20261026-01`. `dc7ba50` is an ancestor of `05bb129`. `backend/src` at `05bb129` is 83 files and about 8,600 lines ahead of `dc7ba50`. No `backend/src` diff was reported between `05bb129` and HEAD `6289d99`.

`staging-20261027-01` was not rebuilt in the session that wrote the tag. Its bytes were not extracted. If the tag was applied without a new build, the running API is `05bb129`, which already contains the current backend source.

## 3. Module comparison

Status `MATCHED` means the route and service exist once in `backend/src` and both deployments build that tree. It does not mean the flow was executed on staging.

| Domain | Status | Evidence |
| --- | --- | --- |
| OTP request, verify, refresh, logout, session | MATCHED | `auth.controller.ts`. `NODE_ENV=production` forces MSG91 or unconfigured. Both task snapshots set `OTP_DELIVERY_PROVIDER=msg91`. Staging SMS was confirmed once earlier. Expiry, resend, and rate-limit behavior were not re-executed. |
| Customer profile | MATCHED | `customer-profile.controller.ts` |
| Rider profile, documents, picture, approval fields | MATCHED | `rider-profile.controller.ts`, `rider-documents.controller.ts`, `rider-profile-picture.controller.ts` |
| Admin login and directory | MATCHED | `admin-auth.controller.ts` has only `POST /v1/admin/auth/login`. Session role is `ADMIN`. Profile role `SUPER_ADMIN` is stored separately and is what finance checks. |
| States, cities, zones, vehicle categories | MATCHED | Admin controllers under `catalog/`. Public `GET /v1/vehicle-categories`. Launch city lookup is active `city_code=AMD`. |
| Fare quote and versioning | MATCHED | `fare.repository.ts`. See section 4. |
| Booking, cancel, assign, accept, reject, status | MATCHED | `orders.controller.ts`, `rider-orders.controller.ts`, `admin-orders.controller.ts` |
| Live location | MATCHED in code, different runtime store | `rider-location.controller.ts`. Production snapshot uses Redis. Staging uses in-memory. |
| Waiting charges | MATCHED | `settlement.repository.ts` and `pickup-wait.math.ts`. One row per order. |
| Commission and rider earnings | MATCHED | Snapshot stores both percentages. `GET /v1/rider/earnings`. |
| Cashfree orders, verify, webhook, refunds | MATCHED in code, isolated by environment | `cashfree-payment.service.ts`, `cashfree-webhook.service.ts`. Staging config is sandbox. Production snapshot is production Cashfree. |
| Payout webhook and reconcile worker | MATCHED in code, staging config off | Production snapshot enables the reconcile worker and maps payout client secrets. Staging does not set the worker and does not map payout client id/secret. `PAYOUT_INSTRUMENT_KEY` is mapped on staging. |
| Push notifications | MATCHED in code, staging provider off | Production snapshot sets `PUSH_PROVIDER=fcm` and the Firebase secret. Staging leaves `PUSH_PROVIDER` unset. With `NODE_ENV=production`, unset push becomes `unconfigured`. |
| Notification worker | MATCHED | Production snapshot sets it true. Staging leaves it unset. Unset with `NODE_ENV=production` defaults to enabled (`configuration.ts`). |
| GST reports and admin finance | MATCHED | `admin-gst-reports.controller.ts`, `admin-finance.controller.ts`, `admin-ledger.controller.ts`, `admin-payment-settings.controller.ts` |
| Routing | MATCHED | Both set `ROUTING_PROVIDER=google` and map `GOOGLE_MAPS_API_KEY`. |

No staging-only controller and no production-only controller were found. Features added after `dc7ba50` (payment verification, payout safety, pickup-wait math, wallet top-up, admin order removal, rider order history, payment settings) are in the current source and in `05bb129`. Copying the older production image back onto staging would remove those features. That was not done.

## 4. Fare and commission

The production formula in `fare.repository.ts` is already the one staging builds:

`distance_charge = ROUND(per_km * distance_km, 2)`

`trip_fare = GREATEST(initial_minimum, ROUND(base_fare + distance_charge + surge + toll + parking, 2))`

`net_payable = ROUND(trip_fare, 2)` and tax is `0`.

The flat `waiting` amount is stored on the quote. It is not added into `trip_fare`. Per-minute waiting is a separate pickup assessment:

- Clock starts at the first `ARRIVED_PICKUP` event and ends at the first `PICKED_UP` event.
- Elapsed minutes are `FLOOR(seconds / 60)`.
- Chargeable minutes are `GREATEST(0, elapsed - initial_waiting_minutes)`.
- Amount is chargeable minutes times the snapshotted `waiting_charge_per_minute`.
- At exactly the free threshold the amount is zero.
- `ON CONFLICT (order_id) DO NOTHING` prevents a second assessment.
- That amount is not given the trip-fare percentage split. `pickup-wait.math.ts` states this explicitly.

`rider_amount = ROUND(trip_fare * rider_percentage / 100, 2)`. Admin publish rejects a split that does not add to 100, and rejects sending only one percentage. If a positive fare is published with both percentages omitted, the code stores 85.00 and 15.00. That default is not an approved commercial rate. Another valid pair, such as 86 and 14, is accepted when both are sent and sum to 100.

No fare code was changed.

## 5. Cashfree

Both environments use `cashfree-payment.service.ts`. The host comes from `CASHFREE_ENVIRONMENT`. Staging tier refuses any value other than sandbox, and refuses a PG host that is not `sandbox.cashfree.com`. The production snapshot sets `CASHFREE_ENVIRONMENT=production`, which selects `https://api.cashfree.com/pg`.

Webhook processing records `(provider, event_id)` with `ON CONFLICT DO NOTHING`. Signature verification lives in the webhook parser. Client success screens are not payment proof.

Refund creation and status mapping exist in `cashfree-payment.service.ts`. They were not called.

## 6. Environment isolation

`IU_DEPLOYMENT_TIER` is the tier switch. `NODE_ENV=production` is set on both snapshots and must not be read as "this is production."

Intentional differences that must stay:

- Database name and host
- Cashfree environment and which secret holds the client id
- CORS origin
- S3 bucket
- MSG91 credential source (production plain env for template and sender; staging Secrets Manager)

Differences that change behavior and need a separate approval before any task-definition edit:

- Staging push is unconfigured. Production snapshot uses FCM.
- Staging location is one process's memory. Production snapshot uses Redis.
- Staging payout reconcile worker is off, and payout client secrets are not mapped.

No production task definition, secret, or database was modified.

## 7. Files changed

This audit added only this report. Shared API behavior was not edited. `idhar_udhar/pubspec.lock` was not edited.

## 8. Tests executed

`npx jest --testPathPatterns "pickup-wait.math.spec|fare.service.spec|payment-settings.spec|configuration.payment.spec|cashfree-webhook.service.spec|vehicle-fare.spec" --no-coverage`

Result: 7 suites passed, 59 tests passed, 0 failed. These are local unit tests with mocks. They do not prove a staging booking or a sandbox payment.

## 9. Aligned

No source patch was required. The current backend already is the API staging should run, and it is a superset of the 2026-10-13 production snapshot.

## 10. Still blocked or not tested

| Item | Status | Why |
| --- | --- | --- |
| Byte identity of image `staging-20261027-01` | NOT TESTED | Tag contents were never extracted. |
| What production ECS is running now | NOT TESTED | No production AWS read in this task. |
| Staging admin, AMD city, vehicle categories, approved fares | BLOCKED | No approved business values. Do not insert zeros. |
| Customer booking through Cashfree sandbox webhook | NOT TESTED | No order or payment was created. |
| Push on staging | REQUIRES APPROVAL | Needs a staging Firebase secret and `PUSH_PROVIDER=fcm` on the staging task only. |
| Shared live location | REQUIRES APPROVAL | Needs staging Redis and `LOCATION_STORE=redis`. |
| Payout reconcile on staging | REQUIRES APPROVAL | Needs sandbox payout client secrets and the worker flag. Do not copy production payout secrets. |

## 11. Business inputs

- Staging admin email and password, only in the process environment of the staging bootstrap.
- Approval to create active Ahmedabad / `AMD`.
- Approved category names, vehicle pairs, fare amounts, free waiting minutes, per-minute waiting rate, and both commission percentages.

## 12. Next staging validation

1. Confirm whether image `staging-20261027-01` was built from `05bb129` or a later commit. Do not deploy during that check.
2. After approval, run the staging admin bootstrap in dry-run, then create only if dry-run reports `action=create`.
3. Create AMD and categories only from approved values.
4. Run one customer booking on a device against `https://staging-api.idharudhar.co.in`, then one Cashfree sandbox payment, and confirm the webhook row and server payment status. Do not treat the app success screen as proof.
