# 09 — System Architecture

## 9.1 High-Level Architecture

```
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│   Customer App     │     │     Rider App      │     │  Admin Panel       │
│   (Flutter)        │     │     (Flutter)      │     │  (Future Web)      │
└─────────┬──────────┘     └─────────┬──────────┘     └─────────┬──────────┘
          │                          │                          │
          └──────────────┬───────────┴──────────────┬───────────┘
                         │                          │
                    Firebase Auth              Custom Claims
                         │                          │
          ┌──────────────┼──────────────────────────┼──────────────┐
          │              │                          │              │
   Cloud Firestore  Cloud Storage            FCM           Crashlytics
          │              │                          │
          └──────┬───────┴──────────────────────────┘
                 │
         Cloud Functions (Node/TypeScript)
                 │
     ┌───────────┼───────────┬──────────────┐
     │           │           │              │
  Matching   Fare/Coupon  Payments     Notifications
  Engine     Validation   Webhooks     Fan-out
     │
 Google Maps Platform (Maps / Places / Directions)
```

## 9.2 Architectural Style

- **Client-server with BaaS**: Flutter clients + Firebase
- **Event-driven ops**: Booking status changes trigger Functions → FCM
- **Clean-ish feature architecture** in Flutter: Presentation → Application → Domain → Data
- **CQRS-lite**: Clients read Firestore snapshots; complex writes go through Functions for invariants

## 9.3 App Layering (Flutter)

```
Presentation (Screens, Widgets, GoRouter)
        ↓
Application (Riverpod Notifiers / Controllers)
        ↓
Domain (Entities, Use cases, Failures)
        ↓
Data (Repositories, DTOs, Dio, Firebase datasources, Hive)
```

## 9.4 Multi-App Strategy

| Approach | Decision |
|----------|----------|
| Repo layout | Monorepo with Melos or simple multi-package |
| Apps | `apps/customer_app`, `apps/rider_app` |
| Shared | `packages/iu_core`, `packages/iu_design_system`, `packages/iu_domain` |
| Admin | Separate future web repo or `apps/admin_web` later |

## 9.5 Core Domain Services

| Service | Responsibility |
|---------|----------------|
| AuthService | Sign-in, OTP, session |
| UserProfileService | Customer/rider profiles |
| LocationService | Geolocator + permission |
| PlacesService | Autocomplete & place details |
| DirectionsService | Distance/duration matrix |
| FareService | Estimate & finalize fare |
| BookingService | Create/update booking |
| MatchingService | (Cloud) assign riders |
| TrackingService | Live location publish/subscribe |
| PaymentService | Cash mark + gateway |
| NotificationService | Token + preference |
| KYCService | Document upload + status |
| WalletService | Rider earnings & payouts |
| SupportService | Tickets |

## 9.6 Booking Status State Machine

```
draft → searching → assigned → en_route_pickup → arrived_pickup
  → picked_up → en_route_drop → arrived_drop → delivered
  → payment_pending → completed

Any active (pre-delivered) → cancelled (policy)
searching → expired (no rider)
```

Invalid transitions must be rejected by Cloud Functions.

## 9.7 Realtime Channels

| Data | Mechanism |
|------|-----------|
| Booking status | Firestore document listener |
| Rider location during trip | Firestore `trips/{id}/location` or RTDB (evaluate) |
| Incoming job requests | FCM high-priority + Firestore request doc |
| Chat (future) | Firestore subcollection |

**Decision note:** Prefer Firestore for MVP simplicity; evaluate Realtime Database for high-frequency location if write costs/latency demand it.

## 9.8 External Integrations

| System | Use |
|--------|-----|
| Google Maps SDK | Map render |
| Places API | Search |
| Directions API | Route & distance |
| FCM | Push |
| Payment gateway (Razorpay recommended) | Online pay V1.1 |
| SMS OTP provider | If not using Firebase Phone Auth exclusively |

## 9.9 Environments

| Env | Firebase Project | Bundle IDs |
|-----|------------------|------------|
| Dev | idhar-udhar-dev | `.dev` suffix |
| Staging | idhar-udhar-stg | `.stg` |
| Prod | idhar-udhar-prod | production |

Flavor-based Flutter builds (`dev`, `stg`, `prod`).

## 9.10 Scalability Considerations

- Shard busy collections by `cityId` in queries
- Cap open listeners per screen
- Paginate history with `startAfter`
- Batch FCM via topics + device tokens
- Use Cloud Tasks for delayed timeouts (request expiry)

## 9.11 Admin Integration Points (Future)

- Same Firestore databases
- Admin SDK for privileged ops
- Custom claims: `role: admin|ops|support`
- Read models / aggregation exports for analytics
