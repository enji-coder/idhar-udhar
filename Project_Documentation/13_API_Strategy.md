# 13 — API Strategy

## 13.1 API Layers

| Layer | Technology | Used For |
|-------|------------|----------|
| Direct SDK | FlutterFire | Auth, simple profile CRUD, realtime listeners |
| Callable HTTPS | Cloud Functions | Invariants: fare, match accept, coupons, payments |
| REST HTTPS | Cloud Functions | Webhooks (payments, SMS) |
| Google APIs | Maps Platform | Places, Directions, Distance |
| Payment API | Razorpay (proposed) | Checkout & refunds |

**Rule:** Anything that can be spoofed by a client (fare, accept race, coupon) MUST be a server Function.

## 13.2 Client Networking Stack

- **Dio** for HTTP (Functions + Google REST + gateway)
- Interceptors: auth bearer, request id, logging (redacted), retry (idempotent GETs)
- Timeouts: connect 10s, receive 30s (Directions may need more)
- Typed responses → Freezed DTOs → Domain mappers

## 13.3 Callable API Catalog (Contract Draft)

### `calculateFare`

**Request:** pickup, drop, vehicleCategoryId, weightKg, couponCode?  
**Response:** distanceKm, durationMin, breakdown, total, currency=`INR`

### `createBooking`

**Request:** fareSessionId or fare payload hash, parcel, locations…  
**Response:** bookingId, status=`searching`

### `cancelBooking`

**Request:** bookingId, reason  
**Response:** status, cancellationFee?

### `respondToJob`

**Request:** requestId, accept:boolean  
**Response:** tripId? or rejection reason (`already_taken`)

### `confirmPickup` / `confirmDelivery`

**Request:** bookingId, otp?, proofUrl?  
**Response:** new status

### `applyCoupon`

**Request:** code, fareContext  
**Response:** discount, newTotal

### `markCashReceived` (rider)

**Request:** bookingId  
**Response:** paymentStatus=`paid`

## 13.4 Google APIs Usage Policy

| API | When | Cache |
|-----|------|-------|
| Places Autocomplete | User typing | Session tokens |
| Place Details | On select | Store placeId + latlng on booking |
| Directions / Distance Matrix | Fare estimate & route | Cache by rounded lat pair + vehicle |

Never ship unrestricted API keys; use bundle ID / SHA restrictions + proxies if needed.

## 13.5 Versioning

- Callable names stable; add optional fields backward-compatibly
- Breaking changes → new function name suffix `V2`
- Clients send `appVersion` + `platform` headers

## 13.6 Error Contract

```json
{
  "code": "COUPON_EXPIRED",
  "message": "This coupon is no longer valid",
  "details": {}
}
```

Map to domain `Failure` types in the app (see Error Handling).

## 13.7 Idempotency

- `createBooking` accepts `Idempotency-Key` header (client-generated UUID)
- Payment webhooks verify signature & process once

## 13.8 Rate Limiting

- Per-uid quotas on fare calculate & OTP
- App Check + Functions rate limits

## 13.9 Admin APIs (Future)

Admin Panel uses Firebase Admin SDK / privileged HTTPS endpoints—not exposed to mobile clients.
