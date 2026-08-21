# 11 — Database Architecture

## 11.1 Principles

1. **Document-oriented** on Cloud Firestore
2. **Denormalize for reads** (trip cards, rider public profile snapshots)
3. **Normalize for money & status** (single source of truth on booking)
4. Every document: `createdAt`, `updatedAt`, `createdBy` where applicable
5. Soft status fields over physical deletes
6. `cityId` on operational documents for multi-city scale

## 11.2 Collection Map

```
users/{userId}
riders/{riderId}
vehicles/{vehicleId}
vehicle_categories/{categoryId}
bookings/{bookingId}
  └─ events/{eventId}                 # audit trail
trips/{tripId}                        # optional 1:1 with booking when assigned
  └─ location/{latest}                # or single field updates
fares_config/{cityId}
coupons/{couponId}
coupon_redemptions/{id}
payments/{paymentId}
wallets/{riderId}
  └─ ledger/{entryId}
ratings/{ratingId}
notifications/{notificationId}
support_tickets/{ticketId}
app_config/{docId}
cities/{cityId}
geofences/{geofenceId}
```

## 11.3 Key Document Schemas (Logical)

### users/{userId}

| Field | Type | Notes |
|-------|------|-------|
| role | string | `customer` \| `rider` \| `admin` |
| fullName | string | |
| mobile | string | E.164 |
| email | string? | |
| photoUrl | string? | |
| fcmTokens | map | deviceId → token |
| isBlocked | bool | |
| cityId | string? | last/home city |
| createdAt | timestamp | |
| updatedAt | timestamp | |

### riders/{riderId}

| Field | Type | Notes |
|-------|------|-------|
| userId | string | = auth uid |
| kycStatus | string | `pending` \| `approved` \| `rejected` |
| kycRejectionReason | string? | |
| isOnline | bool | |
| lastLocation | geopoint | |
| geohash | string | for queries |
| vehicleId | string? | |
| ratingAvg | number | |
| ratingCount | number | |
| documents | map | storage paths + meta |
| cityId | string | |

### vehicle_categories/{categoryId}

| Field | Type | Notes |
|-------|------|-------|
| name | string | Bike, Pickup, Mini Truck |
| capacityKg | number | |
| baseFare | number | |
| perKm | number | |
| perKgExtra | number? | |
| iconUrl | string | |
| sortOrder | number | |
| isActive | bool | |

### bookings/{bookingId}

| Field | Type | Notes |
|-------|------|-------|
| customerId | string | |
| riderId | string? | |
| cityId | string | |
| status | string | state machine |
| pickup | map | address, latlng, placeId |
| drop | map | address, latlng, placeId |
| parcel | map | type, weightKg, notes, photos[] |
| vehicleCategoryId | string | |
| distanceKm | number | |
| durationMin | number? | |
| fare | map | breakdown + currency INR |
| couponId | string? | |
| paymentStatus | string | `unpaid` \| `paid` \| `refunded` |
| paymentMethod | string? | `cash` \| `upi` \| … |
| searchExpiresAt | timestamp? | |
| timeline | map | status → timestamp |
| cancelReason | string? | |

### coupons/{couponId}

| Field | Type | Notes |
|-------|------|-------|
| code | string | uppercase |
| type | string | `percent` \| `flat` |
| value | number | |
| minFare | number? | |
| maxDiscount | number? | |
| cityIds | array | empty = all |
| startsAt / endsAt | timestamp | |
| usageLimit | number? | |
| usedCount | number | |
| isActive | bool | |

### wallets/{riderId}/ledger/{entryId}

| Field | Type | Notes |
|-------|------|-------|
| type | string | `credit` \| `debit` |
| amount | number | |
| bookingId | string? | |
| note | string | |
| createdAt | timestamp | |

### ratings/{ratingId}

| Field | Type | Notes |
|-------|------|-------|
| bookingId | string | |
| fromUserId | string | |
| toUserId | string | |
| stars | number | 1–5 |
| comment | string? | |
| createdAt | timestamp | |

## 11.4 Indexes (Planned)

- `bookings`: `customerId` + `createdAt` DESC
- `bookings`: `riderId` + `createdAt` DESC
- `bookings`: `cityId` + `status` + `createdAt`
- `riders`: `cityId` + `isOnline` + `geohash` (strategy TBD)
- `coupons`: `code` (unique via Functions)

## 11.5 Geolocation Strategy

**MVP recommendation:**

- Store `GeoPoint` + `geohash` on riders
- Matching Function queries candidates by city + online + vehicle, then filters by Haversine distance in memory for pilot scale
- Graduate to GeoFirestore / custom geo library when density requires

## 11.6 Consistency Rules

- Booking status transitions only via Cloud Functions (Admin SDK) for critical paths
- Fare lock snapshot stored on booking at confirm time
- Coupon redemption transactional (Function)

## 11.7 Data Retention

| Data | Policy (proposal) |
|------|-------------------|
| Completed bookings | 7 years (finance) |
| KYC images | Until account closed + legal hold |
| Location breadcrumb | 30–90 days |
| FCM tokens | Remove on logout/uninstall signal |

Validate with legal before production.

## 11.8 Admin Read Models (Future)

Optional aggregation collections:

- `stats_daily/{cityId_date}`
- `ops_live_bookings/{cityId}`
