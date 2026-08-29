# IDHAR UDHAR — BACKEND ARCHITECTURE

**Type:** Implementation architecture (Phase 1)  
**Date:** 2026-08-24  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, locked business rules, PostgreSQL schema  

This file describes the **running** modular monolith. Master Architecture remains the authority for business rules.

---

## 1. Shape

One NestJS TypeScript process. Not microservices.

```text
Flutter / Admin  →  HTTPS /v1  →  NestJS API
                                      │
                                      ├── PostgreSQL (existing idhar_udhar)
                                      ├── Redis* (not in Phase 1)
                                      ├── Object storage* (not in Phase 1)
                                      └── Workers* (not in Phase 1)
```

Package: `backend/` (`idhar-udhar-api`).

---

## 2. Module layout

| Module | Responsibility | Phase 1 contents |
|---|---|---|
| `config` | Env loading and fail-fast validation | `DATABASE_*`, JWT, CORS, TTL |
| `database` | `pg` pool | Query helper, ping |
| `common` | Cross-cutting | JSON logs, request ID, `/v1` error filter |
| `health` | Liveness / readiness | `/health`, `/health/live`, `/health/db` |
| `auth` | Session + tokens + guards | JWT access, hashed refresh, logout |
| orders / fare / wallet / COD / payments / notifications | Domain modules | **Not created in Phase 1** |

Controllers stay thin. Auth domain logic lives in `AuthService`. SQL for sessions lives in `SessionRepository`.

---

## 3. Configuration

Loaded from, first match wins per variable:

1. `backend/.env`
2. `records_database/.env` (typical home of `DATABASE_*`)

Required: `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`, `JWT_ACCESS_SECRET` (≥32), `REFRESH_TOKEN_PEPPER` (≥32).

TTL minutes are **configurable engineering defaults**, not locked product rules:

| Variable | Default |
|---|---|
| `JWT_ACCESS_TTL_SECONDS` | 900 (15 minutes) |
| `JWT_REFRESH_TTL_SECONDS` | 2592000 (30 days) |

See `backend/.env.example` and `records_database/.env.example` (names only).

The API never embeds credentials in Flutter. The process does not log passwords, JWT secrets, or raw refresh tokens.

---

## 4. HTTP surface (Phase 1)

Unversioned (load balancers):

| Method | Path | Auth |
|---|---|---|
| GET | `/health` | Public |
| GET | `/health/live` | Public |
| GET | `/health/db` | Public |

Versioned:

| Method | Path | Auth |
|---|---|---|
| POST | `/v1/auth/token/refresh` | Refresh token in JSON body |
| POST | `/v1/auth/logout` | Bearer access JWT |
| GET | `/v1/auth/session` | Bearer access JWT |
| GET | `/v1/auth/admin-ping` | Bearer + role `ADMIN` |

OTP request/verify and Admin password login are **not** implemented in Phase 1. `AuthService.createSession()` is the internal seam those flows will call later.

---

## 5. Error standard

Every failed API response:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [{ "field": "refresh_token", "message": "..." }],
    "request_id": "uuid"
  }
}
```

`details` is omitted when empty. SQL, stack traces, and secrets are never included. `x-request-id` is always set (incoming header or generated).

---

## 6. Authentication foundation

Access token: JWT (`sub` = identity_id, `sid` = session_id, `role` = CUSTOMER|RIDER|ADMIN, `pid` = profile_id).

Refresh token: opaque random value. Only `sha256(pepper + raw)` is stored in `sessions.refresh_token_hash`. Rotation uses `UPDATE … WHERE refresh_token_hash = $current` so a reused token fails.

Logout sets `sessions.revoked_at`. Subsequent access JWT checks load that row and return `SESSION_REVOKED`.

Guards:

- `JwtAuthGuard` (global) — skip `@Public()`
- `RolesGuard` (global) — enforce `@Roles(...)` when present

A Customer token cannot call Admin-only routes.

---

## 7. Database

Uses the **existing** local PostgreSQL 17 database. Phase 1 runs `SELECT` / `INSERT` / `UPDATE` on `identities`, `customer_profiles` (tests only), and `sessions`. No migrations. No DROP. No schema rewrite.

Connection pooling: `pg.Pool` (`DATABASE_POOL_MAX`, default 10). PostgreSQL remains the financial system of record; Redis is not used yet.

---

## 8. Logging

JSON lines to stdout/stderr:

`ts`, `level`, `msg`, `request_id`, `service`, plus fields such as `method`, `path`, `status`, `duration_ms`.

---

## 9. How to run locally

From `backend/`:

```powershell
copy .env.example .env
# set JWT_ACCESS_SECRET and REFRESH_TOKEN_PEPPER (>= 32 chars)
# DATABASE_* may be left to records_database/.env
npm install
npm run start:dev
```

Health: `GET http://localhost:3000/health`

Tests: `npm test` (unit) and `npm run test:e2e` (requires the existing Docker Postgres).

---

## 10. Next

Phase 2: identity APIs, OTP challenge hashing, Admin password verify, profiles, KYC/vehicles — still no fare/wallet/COD.
