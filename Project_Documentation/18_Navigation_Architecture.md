# 18 — Navigation Architecture

## 18.1 Router

**GoRouter** with declarative routes, redirects for auth/KYC gates, and deep link readiness.

## 18.2 Customer App Route Map

| Path | Screen | Notes |
|------|--------|-------|
| `/splash` | Splash | Initial |
| `/onboarding` | Onboarding carousel | First launch |
| `/login` | Login | |
| `/register` | Register | |
| `/otp` | OTP verify | query: purpose |
| `/forgot-password` | Forgot password | |
| `/reset-password` | Reset | after OTP |
| `/location-permission` | Permission education | |
| `/home` | Home | shell |
| `/booking/pickup` | Pickup | |
| `/booking/drop` | Drop | |
| `/booking/parcel` | Parcel type/details | |
| `/booking/weight` | Weight | |
| `/booking/vehicle` | Vehicle | |
| `/booking/fare` | Fare + coupon | |
| `/booking/confirm` | Confirm | |
| `/tracking/:bookingId` | Live tracking | |
| `/history` | Order history | |
| `/history/:bookingId` | Trip detail | |
| `/payment/:bookingId` | Payment | |
| `/rating/:bookingId` | Rating | |
| `/profile` | Profile | |
| `/settings` | Settings | |
| `/support` | Help & support | |
| `/notifications` | Notification list | |

### Customer Shell

Bottom nav (post-auth): Home · History · Notifications · Profile (exact tabs TBD in UI phase; keep ≤ 5).

## 18.3 Rider App Route Map

| Path | Screen | Notes |
|------|--------|-------|
| `/splash` | Splash | |
| `/onboarding` | Optional | |
| `/login` `/register` `/otp` | Auth | |
| `/kyc/documents` | Document upload | |
| `/kyc/vehicle` | Vehicle registration | |
| `/kyc/pending` | Waiting approval | |
| `/home` | Home + online toggle | gated by KYC |
| `/requests/active` | Incoming request | overlay/full |
| `/trip/:bookingId` | Active trip | |
| `/navigation/:bookingId` | Nav helper | may launch external Maps |
| `/earnings` | Earnings | |
| `/wallet` | Wallet | |
| `/history` | Trip history | |
| `/profile` | Profile | |
| `/settings` | Settings | |
| `/support` | Support | |
| `/notifications` | Notifications | |

## 18.4 Redirect Guards

| Condition | Redirect |
|-----------|----------|
| Not authenticated | `/login` |
| Authenticated + onboarding incomplete | `/onboarding` |
| Authenticated + location undecided (customer) | `/location-permission` once |
| Rider KYC not approved | `/kyc/*` |
| Rider blocked | `/blocked` |
| Force update flag | `/force-update` |

## 18.5 Deep Links (V1.1)

- `idharudhar://tracking/{bookingId}`
- `https://app.idharudhar.in/t/{bookingId}`

## 18.6 Navigation Rules

- Pass IDs in path params; avoid huge extra objects
- Booking draft kept in Riverpod, not route extras
- Pop until home after booking complete
- Use `context.push` for funnel; `go` for tab roots

## 18.7 Analytics Hooks

Log `screen_view` on GoRouter `observers` / redirect listeners.
