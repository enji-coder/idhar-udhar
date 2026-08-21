# 14 — State Management

## 14.1 Choice

**Riverpod** (latest stable) as the single state management approach for Customer and Rider apps.

Rationale: compile-safe DI, testability, async support, clear invalidation, scales across features without BuildContext coupling.

## 14.2 Provider Taxonomy

| Type | Use |
|------|-----|
| `Provider` | Pure services, repositories, config |
| `FutureProvider` | One-shot reads |
| `StreamProvider` | Firestore snapshots (booking, trip location) |
| `Notifier` / `AsyncNotifier` | Forms, controllers, mutable feature state |
| `StateProvider` | Ultra-local ephemeral UI (avoid overuse) |

## 14.3 Layering with Providers

```
presentation → watches Notifier / AsyncValue
Notifier → calls UseCase / Repository
Repository → Firebase / Dio / Hive
```

Presentation never imports FlutterFire directly.

## 14.4 Feature State Examples (Conceptual)

### Auth

- `authStateChangesProvider` → Stream of user
- `loginControllerProvider` → AsyncNotifier for form submit

### Booking Funnel

- `bookingDraftProvider` → holds pickup, drop, parcel, vehicle, coupon
- `fareEstimateProvider` → family keyed by draft hash
- Invalidating draft fields invalidates fare

### Live Tracking

- `activeBookingProvider` → stream
- `tripLocationProvider(bookingId)` → stream

### Rider Availability

- `riderOnlineController` → toggles + side effects (location stream start/stop)

## 14.5 Side Effects Policy

- Navigation side effects: listen in UI with `ref.listen`
- One-time events (snackbars): `AsyncValue` error/data handling or dedicated event channel
- Avoid doing navigation inside repositories

## 14.6 Code Generation

- Prefer `riverpod_annotation` + `riverpod_generator` for maintainability
- Freezed for immutable state objects & DTOs

## 14.7 Testing Strategy for State

- Unit test Notifiers with mocked repositories
- Override providers in `ProviderContainer` / `ProviderScope`
- No Firebase in unit tests

## 14.8 Anti-Patterns

- Global mutable singletons outside Riverpod
- God controllers spanning unrelated features
- Storing BuildContext in providers
- Duplicate sources of truth (draft in UI + provider)

## 14.9 Cross-App Shared State

Shared packages expose interfaces; each app wires Firebase implementations in `bootstrap.dart` via overrides if needed.
