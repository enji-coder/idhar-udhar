# IDHAR UDHAR — AUTHENTICATION ARCHITECTURE

**Type:** Phase 2 implementation notes  
**Date:** 2026-08-24  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, locked business rules, PostgreSQL schema  

---

## 1. Identity model

One `identities` row per phone. Customer and Rider are **profiles** on that identity, not separate logins.

```text
phone OTP
   → identities (unique phone_normalized)
        ├─ customer_profiles (0..1)
        ├─ rider_profiles (0..1)
        └─ admin_profiles (0..1, email + Argon2id password — not OTP)
```

Admin V1 login is email + password on `admin_profiles.password_hash`. Putting Admin on a Customer/Rider identity is not a required product path.

---

## 2. OTP flow

```text
POST /v1/auth/otp/request { phone, actor_type: CUSTOMER|RIDER }
  normalize phone
  rate-limit by IP (configurable)
  enforce cooldown (architecture lock: 30s; tests may set 0)
  generate code (length is a DEVELOPMENT DEFAULT)
  store HMAC-SHA256(pepper, phone + code) in otp_challenges.code_hash
  consume previous open challenges for that phone
  deliver via OtpDeliveryProvider (no plaintext in HTTP or logs)

POST /v1/auth/otp/verify { phone, actor_type, code }
  SELECT latest challenge FOR UPDATE
  reject expired / consumed / max attempts / mismatch
  consume challenge
  upsert identity + actor profile
  create sessions row + JWT + rotating refresh (Phase 1)
```

Plaintext OTP is never stored. `code_hash` is HMAC-SHA256, not the code.

**NEEDS BUSINESS DECISION (not locked here):** OTP length, expiry minutes, max attempts, lockout duration, SMS vendor.  
**Locked:** never store plaintext; 30-second resend cooldown in production config default.

---

## 3. Delivery provider

`OtpDeliveryProvider`:

| Mode | When | Behavior |
|---|---|---|
| `capture` | development / tests (`OTP_DELIVERY_PROVIDER=capture`) | In-memory last code for tests. Not an HTTP field. Not SMS. |
| `unconfigured` | production default until a vendor is chosen | Challenge is stored. No SMS. Log `otp_delivery_unconfigured` with masked phone only. |

Do not treat `capture` as a production SMS integration.

---

## 4. Sessions

Reuses Phase 1:

- Access JWT (`sub`, `sid`, `role`, `pid`)
- Refresh hashed in `sessions.refresh_token_hash`
- Rotation and logout unchanged

---

## 5. HTTP (Phase 2)

| Method | Path | Auth |
|---|---|---|
| POST | `/v1/auth/otp/request` | Public |
| POST | `/v1/auth/otp/verify` | Public |
| POST | `/v1/auth/token/refresh` | Refresh body |
| POST | `/v1/auth/logout` | Bearer |
| GET | `/v1/auth/session` | Bearer |
| POST | `/v1/admin/auth/login` | Public |
| GET | `/v1/customer/profile` | CUSTOMER |
| GET | `/v1/rider/profile` | RIDER |
| GET | `/v1/admin/profile` | ADMIN |

Profiles are always the authenticated principal. There is no “lookup by id in the URL” API.

Responses never include `code_hash`, `password_hash`, or `refresh_token_hash`.

---

## 6. Schema

No migrations. Tables used: `identities`, `otp_challenges`, `sessions`, `customer_profiles`, `rider_profiles`, `admin_profiles`.
