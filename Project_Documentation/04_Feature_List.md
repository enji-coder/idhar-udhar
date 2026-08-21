# 04 — Feature List

## 4.1 Legend

| Tag | Meaning |
|-----|---------|
| MVP | Required for first production launch |
| V1.1 | Near-term after MVP |
| Future | Roadmap / Admin-era |
| Shared | Used by both Customer & Rider |

---

## 4.2 Customer App Features

### Authentication & Onboarding

| Feature | Priority |
|---------|----------|
| Splash screen with brand loading | MVP |
| Onboarding carousel (3 screens) | MVP |
| Phone / password registration | MVP |
| Login (mobile + password) | MVP |
| OTP verification | MVP |
| Forgot password → Send OTP → Reset | MVP |
| Social login (Google / Apple) | V1.1 |
| Remember me | MVP |
| Terms & conditions acceptance | MVP |
| Location permission education screen | MVP |
| Skip onboarding | MVP |

### Booking Core

| Feature | Priority |
|---------|----------|
| Home dashboard | MVP |
| Set pickup location (map + Places search) | MVP |
| Set drop location (map + Places search) | MVP |
| Saved / recent addresses | V1.1 |
| Parcel type selection | MVP |
| Parcel details (description, photos optional) | MVP |
| Weight selection / slab | MVP |
| Vehicle selection (bike, pickup, mini truck, etc.) | MVP |
| Fare estimation (distance + vehicle + weight) | MVP |
| Apply coupon / promo | MVP |
| Booking confirmation | MVP |
| Booking status timeline | MVP |

### Live Ops

| Feature | Priority |
|---------|----------|
| Live tracking on Google Maps | MVP |
| Rider details (name, photo, vehicle, rating) | MVP |
| ETA display | MVP |
| In-app chat / call rider | V1.1 |
| Cancel booking (rules-based) | MVP |
| Pickup / drop confirmation visibility | MVP |
| Push notifications (status changes) | MVP |

### Payments & History

| Feature | Priority |
|---------|----------|
| Fare breakdown view | MVP |
| Cash payment option | MVP |
| UPI / online payment (Razorpay or similar) | V1.1 |
| Payment success / failure states | MVP |
| Order / trip history | MVP |
| Trip detail & invoice stub | MVP |
| Rate & review rider | MVP |

### Account

| Feature | Priority |
|---------|----------|
| Profile view / edit | MVP |
| Settings | MVP |
| Notification preferences | V1.1 |
| Help & Support (FAQ + ticket) | MVP |
| Logout / delete account request | MVP |

---

## 4.3 Rider App Features

### Authentication & KYC

| Feature | Priority |
|---------|----------|
| Splash / onboarding | MVP |
| Registration & login | MVP |
| OTP verification | MVP |
| Document verification (Aadhaar/DL/RC uploads) | MVP |
| Vehicle registration | MVP |
| KYC status (pending / approved / rejected) | MVP |
| Profile photo | MVP |

### Availability & Jobs

| Feature | Priority |
|---------|----------|
| Online / Offline toggle | MVP |
| Incoming booking request card | MVP |
| Accept / Reject order | MVP |
| Request timeout handling | MVP |
| Active trip screen | MVP |
| Google Navigation to pickup / drop | MVP |
| Pickup confirmation (OTP / button) | MVP |
| Delivery confirmation (OTP / proof photo) | MVP |

### Money & Reputation

| Feature | Priority |
|---------|----------|
| Earnings dashboard (today / week / month) | MVP |
| Wallet balance & payout history | MVP |
| Trip history | MVP |
| Ratings received | MVP |
| Incentives display | V1.1 |

### Account

| Feature | Priority |
|---------|----------|
| Notifications | MVP |
| Profile & settings | MVP |
| Help & Support | MVP |
| Logout | MVP |

---

## 4.4 Admin Panel Features (Architecture Ready — Not Built Now)

| Module | Capability |
|--------|------------|
| Customer Management | List, search, suspend, view bookings |
| Rider Management | KYC approve/reject, suspend, vehicle review |
| Vehicle Management | Categories, base fares, capacity rules |
| Booking Management | Live map, force cancel, reassign |
| Payments | Payout batches, refunds, disputes |
| Offers | Coupons create / schedule / limit |
| Notifications | Broadcast / segment push |
| Analytics | Demand heat, conversion funnels |
| Reports | CSV/PDF exports |
| Settings | Cities, surge, app config remote |

---

## 4.5 Shared / Platform Features

| Feature | Priority |
|---------|----------|
| FCM push notifications | MVP |
| Crashlytics | MVP |
| Analytics events | MVP |
| Deep links (booking / referral) | V1.1 |
| Multi-city configuration | MVP (data model) |
| Force update / remote config | V1.1 |
| Referral program | Future |
| Multi-language (Hindi+) | Future |

## 4.6 Feature Dependency Graph (High Level)

```
Auth → Location Permission → Home
Home → Pickup → Drop → Parcel → Vehicle → Fare → Coupon → Book
Book → Matching → Live Tracking → Payment → Rating → History

Rider: Auth → KYC → Online → Request → Accept → Nav → Confirm → Earnings
```
