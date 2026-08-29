# IDHAR UDHAR — FINAL RUNTIME INTEGRATION AUDIT

**Date:** 2026-08-26  
**Scope:** Make Customer Chrome, Rider Chrome, local Admin, Nest `/v1`, and Docker PostgreSQL work together in development.  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, UI design, migrations, Firebase, MSG91, Redis, payment provider, production Google Maps.

This file records what was actually verified. It is not a production-readiness certificate.

---

## 1. Current architecture

Unchanged modular monolith:

```
Customer Flutter  ─┐
Rider Flutter     ─┼─► NestJS /v1 (localhost:3000) ─► PostgreSQL 17.11 `idhar_udhar` (Docker)
Admin (Vite/local)─┘
```

- Schema owner: `records_database/migrations/` (not ORM).
- Money, fare, 85/15, wallet, COD: server + PostgreSQL NUMERIC.
- Routing: `ROUTING_PROVIDER=mock` for this run (honest mock, not labelled Google).
- Location: in-memory store (not Redis).
- OTP delivery: `capture` (in-process). SMS vendor not integrated.
- Push: `capture` / unconfigured. FCM not integrated.
- Payments: unconfigured provider. ONLINE is not faked as PAID.

## 2. Applications

| App | Location | How it was run this session |
|---|---|---|
| Customer | `idhar_udhar/` flavor `customer` | Chrome `http://127.0.0.1:7357` |
| Rider | same repo, flavor `rider` | Chrome `http://127.0.0.1:7358` |
| Admin | `IDHAR_UDHAR_ADMIN/` | Local Vite `http://localhost:5173` |
| Admin (hosted) | `https://idhar-udhar-admin.netlify.app` | Opened; **cannot** use local HTTP API |
| API | `backend/` | `node dist/main.js` on port 3000 |
| Database | Docker `idhar_udhar_postgres` | Existing volume, not reset |

## 3. Backend status

**PASS** (development runtime).

Root causes fixed (not “delete dist and hope”):

1. **Stale incremental compile.** `nest-cli` `deleteOutDir: true` plus `tsconfig` `incremental: true` left `tsconfig.build.tsbuildinfo` after `dist/` was gone, so `start:dev` reported `Cannot find module dist/main`. Fix: `backend/tsconfig.build.json` sets `"incremental": false`.
2. **dotenv `#` truncation.** Local `DATABASE_PASSWORD` contains `#`. Nest ConfigModule/dotenv treated `#…` as a comment, so Postgres auth failed while e2e (custom loader) passed. Fix: load env with a first-wins parser that keeps `#` inside values; `ConfigModule.ignoreEnvFile: true`.
3. **CRLF.** Windows `.env` values ended with `\r`. `required()` now `trim()`s.
4. **Watch EADDRINUSE.** `nest start --watch` left an orphan `dist/main.js` on :3000. This session used `node dist/main.js` after a clean build for the verified run.

Health after the fixes:

- `GET /health` → 200, database name **`idhar_udhar`**, version **17.11**
- `GET /health/live` → 200
- `GET /health/db` → 200
- No SQL secrets in those bodies. Stack traces are not returned as public error payloads.

Development OTP peek (loopback only): `GET /v1/auth/dev/otp-capture?phone=` when `NODE_ENV !== production`, `OTP_DELIVERY_PROVIDER=capture`, and `DEV_OTP_PEEK=true`. e2e asserts **404** when the flag is off.

## 4. Database status

**PASS.** Docker container `idhar_udhar_postgres` was already running. Database name `idhar_udhar`. Migrations were **not** changed, dropped, or re-run.

After the live marketplace check, PostgreSQL contained the same state the API returned: order, stops, fare quote, `order_fare_snapshots`, status events, accepted offer, notifications.

Catalog used (already present, not seeded by new migrations):

- City AMD / Ahmedabad `01a0377d-a046-72d5-a745-ea3df4efd17c`
- Vehicle Bike `01a0377d-a067-771a-8be4-ea3481abd1bf`

A local SUPER_ADMIN row was upserted with `backend/scripts/ensure-local-admin.mjs` from `IDHAR_UDHAR_ADMIN/.env` (password hash only; secrets not printed).

## 5. Customer status

**PASS** for development Chrome + live API contract.

- API base: `http://localhost:3000` on Chrome (`ApiConfig`).
- Session keys namespaced with `--dart-define=IU_APP=customer`.
- Create/quote/confirm go to Nest; displayed trip fare after quote is the backend quote (`tax` `0.00`).
- Chrome app launched (`Launching lib/main.dart on Chrome`), `http://127.0.0.1:7357` returned HTTP 200, and the debug client called `/v1/auth/otp/*`.
- Booking still requires `IU_CITY_ID` and `IU_VEHICLE_CATEGORY_ID` dart-defines (no public catalog list API).

Full marketplace clicks inside the Flutter UI were not driven by an automated browser. The same Customer APIs the app uses were executed end-to-end against the live server.

## 6. Rider status

**PASS** for development Chrome + live API contract.

- Separate token namespace `--dart-define=IU_APP=rider`.
- Rider identity from JWT session, not a client-supplied rider id.
- Chrome app launched (`lib/rider/rider_main.dart`), `http://127.0.0.1:7358` HTTP 200.
- Live API: OTP login as an **already APPROVED + ONLINE** rider, see offer, accept (one winner), status hops to `IN_TRANSIT`.
- A **new** OTP rider is created `PENDING` / `OFFLINE` (schema defaults). Admin KYC/online APIs are still mock, so a brand-new Chrome rider cannot receive offers until approved/online in the database.

## 7. Admin status

**PASS** for **local** Admin `http://localhost:5173` against Nest.

- Login: `POST /v1/admin/auth/login` (verified live).
- Orders list saw the Customer-created order (`IU-AMD-0000000651`).
- Offer: `POST /v1/admin/orders/:id/offers`.
- Money fields on API orders come from stored fare/finance snapshots, not JS 85/15.
- Local `npm run lint` exit 0 (pre-existing warnings). `npm test` 7/7. `npm run build` exit 0.

Still mock (unchanged Phase 9 list): KYC, payouts, coupons, vehicles/zones CRUD, invoices, campaign composer, Admin create-order, wallet credit/payout, refunds.

## 8. Netlify status

**FAIL against local backend** (expected, not “fixed” by weakening production).

Exact reasons:

1. **Mixed content.** `https://idhar-udhar-admin.netlify.app` cannot call `http://localhost:3000` from the browser.
2. **Stale bundle.** Deployed JS is `index-CbIZvSgZ.js` and still references `netlify/functions`. Local production build is `index-C1eDsqGo.js` and talks to Nest `/v1`. Netlify is **not** this session’s Phase 9 client.

Safe development method: run Admin on **HTTP** `localhost:5173` → HTTP API. Do not set `origin: '*'`. Do not put a tunnel URL into production Netlify without a dedicated development backend.

## 9. Chrome runtime status

| Surface | Result |
|---|---|
| Customer Chrome :7357 | Running, HTTP 200, called Nest |
| Rider Chrome :7358 | Running, HTTP 200 |
| Admin Vite :5173 | Running, HTTP 200 |
| CORS `http://localhost:5173` | Allowed |
| CORS `http://localhost:7357` | Allowed |
| Interactive Flutter OTP typing | Not automated; loopback peek used for live API OTP |

Use separate Chrome profiles if Customer and Rider share an origin. Ports 7357 vs 7358 are origin-isolated; token keys are also namespaced.

## 10. APK build status

| APK | Path | Verified |
|---|---|---|
| Customer debug | `idhar_udhar/build/app/outputs/flutter-apk/app-customer-debug.apk` | Exists (2026-08-26 12:38, 167,946,863 bytes) |
| Rider debug | `idhar_udhar/build/app/outputs/flutter-apk/app-rider-debug.apk` | Exists (2026-08-26 12:42, 169,082,295 bytes) |

Built with `IU_APP`, `IU_CITY_ID`, `IU_VEHICLE_CATEGORY_ID` dart-defines. **A phone’s `localhost` is not the PC.** These APKs are not a phone-to-PC connectivity test.

## 11. API integration status

Verified live against Nest (not assumed from DTOs):

- Customer OTP request/verify, create, quote (201, trip_fare text, tax `0.00`), confirm → `SEARCHING`
- Admin login, list orders, create offer
- Rider OTP, list offers, accept → `ASSIGNED`, status to `IN_TRANSIT`
- Customer GET order shows assigned rider and later status
- Customer/Rider tokens cannot call `/v1/admin/orders` (403)
- Three tokens distinct
- Quote/confirm do not accept client `distance_km` / trip fare override on create (create DTO has no fare fields)

## 12. End-to-end flow status

**PASS** on the live API + PostgreSQL for display id `IU-AMD-0000000651`.

Stopped only at later hops (`NEAR_DROP` … `DELIVERED`) by choice; `IN_TRANSIT` was enough to prove rider status updates, customer visibility, admin visibility, and notifications (7 rows). ONLINE payment was not faked as PAID.

One-winner concurrent accept remains covered by existing e2e (`offers.e2e-spec.ts`), not re-raced on the live server this session.

## 13. CORS status

**PASS** for development.

- Explicit `CORS_ORIGIN` plus, when `NODE_ENV !== production`, any `http://localhost|127.0.0.1|10.0.2.2` origin.
- Credentials allowed. Not `origin: '*'`.
- Preflight checked for `:5173` and `:7357`.

## 14. Environment status

| File | Role |
|---|---|
| `backend/.env` | JWT + DB for API (not committed) |
| `records_database/.env` | Shared DB fallback (not committed) |
| `IDHAR_UDHAR_ADMIN/.env` | Admin email/password for local SUPER_ADMIN upsert; Vite defaults API to `http://localhost:3000` when not `PROD` |
| `backend/.env.example` | Documents `DEV_OTP_PEEK`, mixed-content note, hash-safe loader |

This session set `DEV_OTP_PEEK=true` in the **process** starting `node dist/main.js`, because writing local `.env` was blocked by policy. Tests force `DEV_OTP_PEEK=false`.

## 15. Known blockers

- Netlify HTTPS Admin cannot use local HTTP Nest (mixed content + stale functions bundle).
- New rider OTP profile is PENDING/OFFLINE; no Admin KYC/online mutation API.
- Flutter create-order needs catalog UUID dart-defines.
- `flutter analyze` exits 1 with 80 pre-existing info/warning lints (1 `strict_raw_type`); not introduced as a runtime defect this session.
- Capture OTP is in-memory: peek is loopback-only; no SMS.
- `nest start --watch` is easy to leave in EADDRINUSE / stale `dist` on Windows; prefer `npm run build` then `node dist/main.js` when diagnosing runtime.
- Unquoted `#` in `.env` passwords must not go through dotenv.

## 16. Production blockers

- Real SMS OTP / MSG91
- Production Google Maps / Routes API key and product travel-mode decision
- FCM (or equivalent) + device tokens
- Payment provider + webhook; authorize vs capture still a business decision
- Redis for hot GPS
- Production Nest hosting (HTTPS)
- Production PostgreSQL
- Object storage
- Domain / SSL
- Monitoring / alerting
- Deployment pipeline; **redeploy Netlify only after a public HTTPS API** with `VITE_API_BASE_URL` set
- Admin KYC / rider online controls
- SEARCHING TTL / dispatch radius still NEEDS BUSINESS DECISION

## 17. Recommended next phase

**Do not start automatically.**

Suggested candidate after confirmation:

**Phase 10 — Hosted development API + Netlify Admin cutover**  
Stand up an HTTPS development Nest (or tunnel used only in development, never committed) so the existing Netlify Admin can call `/v1` without mixed content, then redeploy Admin with `VITE_API_BASE_URL`. Optionally add Admin KYC/online and a catalog list so Flutter Chrome does not need dart-defines.

Alternatively: stay local and add only operator APIs (KYC approve, rider online) if the priority is “new rider in Chrome can take offers.”

Wait for explicit confirmation before starting either.
