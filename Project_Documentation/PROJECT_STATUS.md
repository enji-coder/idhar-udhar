# IDHAR UDHAR — Project Status

> Generated from the **current Flutter codebase** (`idhar_udhar/`).  
> Documents only what exists. Does not invent future features.

**Last reviewed:** 2026-08-08 (Customer UI restored + attached sunset glass theme)

---

## 1. Snapshot

| Field | Value |
|-------|--------|
| App package | `idhar_udhar` |
| App name | IDHAR UDHAR |
| Tagline | Delivering Trust, Every Time |
| Version | `1.0.0+1` |
| Current product focus | **Customer mobile app UI** with dummy data (Rider / Admin later) |
| Backend / Firebase | **Not integrated** |

---

## 2. Customer screens (restored)

**Auth:** Splash, Login, OTP, Profile Setup, Location Permission  
**Main shell:** Dashboard, Orders, Wallet, Profile (+ Edit Profile, Help)  
**Booking:** Pickup, Drop, Vehicle Selection, Package Details, Booking Summary, Searching Rider, Rider Assigned, Tracking, Delivery Completed, Order Details  

**Flow:**  
`splash → login → otp → profile-setup* → location → home shell`  
`book/pickup → drop → vehicle → package → summary → searching → rider-assigned → tracking → completed`

\*Skipped when returning user already has a name (in-memory).

**Bottom nav:** Home · Orders · Wallet · Profile

---

## 3. Theme source of truth

Attached sunset glass reference images drive:

- `AppColors` (orange `#FF6A00`, navy `#183B73`)
- `AppGradients.referenceSunset` + translucent glass fills
- `GlassEffect` / `GlassContainer` / `GlassCard`
- `CinematicBackground` (sunset photo/gradient canvas — **not** navy)

---

## 4. Validation (2026-08-08)

| Check | Result |
|-------|--------|
| `flutter pub get` | Succeeds |
| `flutter analyze lib` | No errors / warnings (info-level lints only) |
| `flutter test` | **PASS** |
| `flutter build apk --debug` | **PASS** |
