# SECURITY ARCHITECTURE

## Current risks (do not print secrets)

- Customer session JSON in **plain SharedPreferences**.  
- Rider login is a boolean flag.  
- Dummy OTPs.  
- Admin accounts and at least one password live in frontend seed data (`adminAccounts.js`).  
- `Project_Documentation/000_info.txt` contains credentials (rotate; never copy into apps).  
- `company.js` holds GSTIN/PAN/bank — OK as company profile, not in mobile apps.  
- Vehicle-categories GET is public (`Access-Control-Allow-Origin: *`); PUT requires admin cookie. Fine for catalog; not for PII.  
- Flutter `pubspec` has secure storage unused.

## Production rules

| Data | Store | Who |
|---|---|---|
| OTP codes | Hash + TTL in Postgres; SMS via server | Nobody’s app |
| Access/refresh tokens | Hash refresh; short-lived JWT access | Apps hold access only |
| Admin passwords | Argon2id server | Never in React bundle |
| Payment provider keys | Server env | Never Flutter/Admin Vite |
| Bank account / UPI | Encrypted column or vault | Finance/ops RBAC |
| Aadhaar/PAN images | Object storage private | Presigned GET, short TTL |
| Customer addresses | Postgres, TLS | Owner + authorized ops |
| Wallet | Server transactions only | |
| Card PAN | **Never stored** — payment provider tokens |

## Auth

- Customer/Rider: phone OTP (length/provider TBD). Rate limit request-otp per phone/IP.  
- Admin: email + password + session cookie HttpOnly Secure SameSite; optional 2FA later.  
- RBAC from existing `permissions.js` roles, evaluated **on API**, not only hiding sidebar.

## Apps

- No Firebase service account in mobile.  
- Certificate pinning optional later.  
- Masking: Rider already masks customer; Admin `masking.js` must remain for list views.  
- Field-level: Sub Admin `financeAccess: false` must be enforced by API on finance routes (already in `canAccessPath`).

## Secrets location

Only backend/CI env: DB URL, Redis, S3, SMS, payment webhook secrets, JWT keys, Netlify/admin session secret (already `netlify/functions/lib/session.js` pattern).
