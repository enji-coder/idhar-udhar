# 08 — User Flows

## 8.1 Customer — First Launch & Auth

```
Splash
  → (first launch?) Onboarding 1 → 2 → 3
  → Login OR Register
  → OTP Verify
  → Location Permission screen
  → System permission dialog
  → Home
```

### Alternate Paths

- Skip onboarding → Login/Register
- Forgot Password → OTP → Reset → Login
- Location “Not Now” → Home (limited) → re-prompt on booking

---

## 8.2 Customer — Complete Booking

```
Home
  → Enter Pickup (map/search)
  → Enter Drop (map/search)
  → Parcel Type
  → Parcel Details / Weight
  → Vehicle Selection
  → Fare Estimate (+ Coupons)
  → Confirm Booking
  → Searching for Rider
  → Rider Assigned
  → Live Tracking
  → Trip Completed
  → Payment (cash/online)
  → Rating
  → Home / History
```

### Decision Points

| Point | Outcomes |
|-------|----------|
| Out of service area | Show blocked state + change location |
| No vehicles for weight | Disable incompatible cards; explain |
| Invalid coupon | Inline error; keep base fare |
| No rider found (timeout) | Retry / cancel / support CTA |
| Cancel mid-trip | Policy check → fee → status `cancelled` |

---

## 8.3 Customer — Track & Support

```
Push: Rider arriving
  → Open Live Tracking
  → Call/Chat (V1.1) or view details
  → Help → Create ticket (optional)
```

---

## 8.4 Rider — Onboarding & KYC

```
Splash → Auth → OTP
  → Document Upload
  → Vehicle Registration
  → KYC Pending screen
  → (Admin approves)
  → Home with Offline toggle enabled
```

### Reject Path

```
KYC Rejected → Show reasons → Re-upload → Pending
```

---

## 8.5 Rider — Job Lifecycle

```
Go Online
  → Location streaming starts
  → Incoming Request (timer)
  → Accept OR Reject / Timeout
  → Navigate to Pickup
  → Confirm Pickup
  → Navigate to Drop
  → Confirm Delivery
  → Earnings updated
  → Available for next job
```

---

## 8.6 Matching Flow (System)

```
Booking created (searching)
  → Query nearby online riders (geo + vehicle type)
  → Push / in-app request to candidates (batched)
  → First Accept wins (transaction)
  → Others notified request taken
  → If none: expand radius / retry / fail gracefully
```

---

## 8.7 Payment Flow

### Cash (MVP)

```
Trip completed → Show amount due → Customer pays cash → Rider marks received → Booking paid
```

### Online (V1.1)

```
Trip completed OR prepaid (policy) → Gateway checkout → Webhook confirms → Booking paid
```

---

## 8.8 Notification Triggers (Minimum)

| Event | Customer | Rider |
|-------|----------|-------|
| OTP sent | Yes | Yes |
| Booking confirmed / searching | Yes | — |
| New job request | — | Yes |
| Rider assigned | Yes | Yes |
| Rider arriving / arrived | Yes | — |
| Pickup confirmed | Yes | Yes |
| Delivered | Yes | Yes |
| Payment update | Yes | Yes |
| KYC status change | — | Yes |
| Promo / broadcast | Yes | Optional |

---

## 8.9 Error & Empty Flow Patterns

Every flow must define:

1. Loading skeleton / glass shimmer
2. Empty state illustration + CTA
3. Recoverable error + Retry
4. Fatal error + Support link
