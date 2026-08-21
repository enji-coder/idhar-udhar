# 12 — Firebase Architecture

## 12.1 Services Used

| Service | Purpose |
|---------|---------|
| Firebase Authentication | Email/password, Phone OTP, (optional) Google/Apple |
| Cloud Firestore | Primary database |
| Firebase Storage | KYC docs, profile photos, parcel photos |
| Firebase Cloud Messaging | Push notifications |
| Firebase Crashlytics | Crash reporting |
| Cloud Functions | Matching, fare finalize, coupons, webhooks, FCM fan-out |
| Firebase App Check | Abuse protection (enable early) |
| Remote Config | Force update, feature flags (V1.1) |
| Analytics | Funnel events |

## 12.2 Auth Model

| Role | Auth Method (MVP) | Claims |
|------|-------------------|--------|
| Customer | Phone + password OR email/password + phone verify | `role: customer` |
| Rider | Same | `role: rider` |
| Admin (future) | Email + strong MFA | `role: admin` |

**Recommendation:** Prefer Firebase Phone Auth for OTP authenticity; password can be app-level or email/password linked. Final choice must be validated (see Assumptions).

## 12.3 Security Rules Outline (Conceptual)

### Firestore

- Default deny
- User can read/write own `users/{uid}` profile fields (limited)
- Bookings: customer create; updates restricted; status changes via Functions only
- Riders: public-safe fields readable by authenticated customers during active trip
- Wallets: rider read own; write Admin SDK only
- Coupons: read active metadata; redeem via Function

### Storage

```
/kyc/{riderId}/{file}     → rider write if owner & pending; admin read
/profiles/{uid}/{file}    → owner write; authenticated read
/parcels/{bookingId}/{file} → customer write on own booking
```

## 12.4 Cloud Functions Catalog

| Function | Trigger | Responsibility |
|----------|---------|----------------|
| `onBookingCreated` | Firestore create | Start matching / set expiry |
| `matchRiders` | Callable / task | Find & notify candidates |
| `onRequestResponse` | Callable | Accept/reject with transaction |
| `expireBookingSearch` | Cloud Tasks | Mark expired |
| `onBookingStatusChanged` | Firestore update | FCM to parties |
| `calculateFare` | Callable | Server-side fare truth |
| `applyCoupon` | Callable | Validate & lock discount |
| `finalizePaymentCash` | Callable | Mark paid |
| `paymentWebhook` | HTTPS | Gateway events |
| `onKycSubmitted` | Firestore | Notify ops |
| `setUserRole` | Auth create | Seed claims + profile docs |
| `aggregateRiderRating` | Rating create | Update averages |

## 12.5 FCM Strategy

- Store tokens under user/rider docs
- Topics: `city_{id}_customers`, `all_riders` (careful)
- Data + notification payloads for background handling
- High priority for job requests

## 12.6 Crashlytics

- Enable in non-debug builds
- Set custom keys: `role`, `cityId`, `bookingId` (when active)
- Non-fatal for handled domain failures of interest

## 12.7 App Check

- Play Integrity / DeviceCheck
- Enforce on Functions callables in staging→prod

## 12.8 Emulator Suite

Local development must support:

- Auth, Firestore, Functions, Storage emulators
- Documented seed scripts for vehicle categories & coupons

## 12.9 Region

Primary: **`asia-south1`** (Mumbai) for Functions & Firestore if available for all products; confirm at project creation.

## 12.10 Cost Control Guards

- Throttle rider location writes (max 1 / 3–5s)
- Paginate listeners
- Avoid unbounded `onSnapshot` on large collections
- Monitor blaze plan budgets & alerts
