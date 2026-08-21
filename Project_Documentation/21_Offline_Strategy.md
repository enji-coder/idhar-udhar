# 21 — Offline Strategy

## 21.1 Objectives

- App remains usable for read paths on flaky Indian mobile networks
- Critical mutations never silently disappear
- Live tracking degrades gracefully when GPS/network drops

## 21.2 Storage Roles

| Store | Data |
|-------|------|
| **Flutter Secure Storage** | Auth tokens, secrets |
| **Hive** | Booking draft, recent addresses, cached configs, vehicle categories |
| **Shared Preferences** | Flags: onboardingComplete, theme, locale |
| **Firestore cache** | SDK persistence enabled for snapshots |

## 21.3 Offline-Capable Features

| Feature | Offline Behavior |
|---------|------------------|
| View profile (cached) | Show last snapshot + stale banner |
| Order history | Show cached page; pull-to-refresh when online |
| Vehicle categories / fare rules | Cache with TTL; block booking if expired & offline |
| Booking draft | Persist locally until submit |
| Help FAQ | Bundle static FAQ assets |
| Live tracking | Freeze last location; show reconnecting |

## 21.4 Online-Required Features

- Create booking
- Accept/reject job
- Payment confirmation
- KYC upload
- Coupon validate (must revalidate online)

## 21.5 Sync Strategy

1. Detect connectivity (connectivity_plus or equivalent—add when implementing)
2. Queue: MVP = **no silent mutation queue**; show “You’re offline” and disable CTA
3. V1.1: optional outbox for non-critical telemetry only
4. On reconnect: invalidate Riverpod providers; refresh active booking streams

## 21.6 Conflict Resolution

- Server wins for booking status
- Local draft merges field-wise until submitted
- Rider online flag: server truth on reconnect

## 21.7 Map Offline

- Do not rely on offline map tiles in MVP
- Cache last known pickup/drop latlng for display as pins on failure

## 21.8 UX Copy

- Banner: “No internet connection. Some actions are unavailable.”
- CTA disabled state with tooltip reason
