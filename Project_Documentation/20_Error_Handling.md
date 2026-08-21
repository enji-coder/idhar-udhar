# 20 — Error Handling

## 20.1 Goals

- Users always see a clear, calm, recoverable message
- Developers get codes + stack via Crashlytics
- Domain failures are typed, not stringly

## 20.2 Error Layers

```
Platform / Firebase / Dio Exception
        → Data source mapping
        → Domain Failure (Freezed union)
        → Presentation message + UX state
```

## 20.3 Domain Failure Categories

| Type | Examples |
|------|----------|
| `NetworkFailure` | Timeout, offline |
| `AuthFailure` | Invalid credentials, OTP invalid |
| `ValidationFailure` | Bad phone, weak password |
| `BookingFailure` | Out of zone, no riders |
| `PaymentFailure` | Gateway declined |
| `PermissionFailure` | Location denied |
| `ServerFailure` | 5xx, unknown codes |
| `UnexpectedFailure` | Parsing, bugs |

## 20.4 User-Facing Copy Guidelines

- Specific: “OTP expired. Tap Resend for a new code.”
- Non-leaking: Don’t say “email not registered” vs “wrong password” inconsistently—use unified auth failure where security requires
- Actionable: always offer Retry / Support when stuck
- Tone: navy calm text; danger color only for true errors

## 20.5 UI Error Patterns

| Pattern | When |
|---------|------|
| Inline field error | Validation |
| Banner / toast | Transient non-blocking |
| Full-screen error | Hard load failure |
| Dialog | Destructive confirm failures |
| Empty + CTA | No history / no coupons |

Glass screens: prefer in-card error text over opaque Material banners that break blur aesthetic.

## 20.6 AsyncValue Handling (Riverpod)

- `loading` → shimmer/skeleton
- `error` → mapped Failure widget
- `data` → content
- Preserve previous data on refresh when possible

## 20.7 Logging & Reporting

| Severity | Action |
|----------|--------|
| Expected domain (wrong OTP) | Log debug; no Crashlytics |
| Unexpected | Crashlytics non-fatal / fatal |
| Payment mismatch | Non-fatal + ops alert |

Include `requestId`, `userId` hash, `bookingId` when safe.

## 20.8 Retry Policy

- Idempotent GETs: exponential backoff 1s/2s/4s, max 3
- Mutations: user-initiated retry only (unless idempotent key present)
- Matching search: automatic retry with UX timer

## 20.9 Global Error Gate

Uncaught Flutter errors → Crashlytics  
Platform dispatcher errors → Crashlytics  
Show generic “Something went wrong” + Support if UI-visible
