# 05 — Project Scope

## 5.1 In Scope (MVP Production Launch)

### Products

- Customer Flutter application (Android + iOS)
- Rider Flutter application (Android + iOS)
- Shared Flutter packages (design system, core, domain models as docs→code later)
- Firebase backend configuration (Auth, Firestore, Storage, FCM, Crashlytics)
- Google Maps / Places / Directions integration
- Documentation package (this folder)

### Customer MVP Capabilities

- Auth (register, login, OTP, forgot password)
- Onboarding + location permission
- Full booking funnel: pickup → drop → parcel → vehicle → fare → coupon → confirm
- Live tracking of active trip
- Cash payment (online payment hook prepared)
- History, ratings, profile, help

### Rider MVP Capabilities

- Auth + document KYC + vehicle registration
- Online/offline + accept/reject
- Navigation + pickup/delivery confirmation
- Earnings, wallet view, trip history, ratings, notifications

### Ops Interim

- Manual KYC approval via Firebase Console / temporary internal tools until Admin Panel

## 5.2 Out of Scope (MVP)

| Item | Reason |
|------|--------|
| Admin Panel UI | Explicitly deferred; architecture only |
| Inter-city freight | Complexity; city launch first |
| Warehouse / hub logistics | Future |
| In-app chat | V1.1 |
| Full online payments (if gateway not ready) | V1.1; cash MVP |
| Multi-language | Future (English MVP) |
| Desktop web customer portal | Future |
| White-label APIs | Future |
| Dynamic surge ML pricing | Future (rule-based ok) |
| Hardware POS / thermal printers | Out |

## 5.3 Geographic Scope

- Launch cities: configurable list (recommend 1–2 pilot cities)
- Serviceable geofences per city
- Out-of-service messaging when pickup/drop outside zone

## 5.4 Platform Scope

| Platform | MVP |
|----------|-----|
| Android (API 24+) | Yes |
| iOS (iOS 14+) | Yes |
| Web Admin | No (future) |
| Web Customer | No |

## 5.5 Compliance Scope (MVP Baseline)

- Privacy policy & terms links in-app
- Location used only for booking/tracking (as shown in UI copy)
- Secure storage of auth credentials
- Soft account deletion request flow
- Full legal/compliance counsel review is a pre-launch gate (assumption)

## 5.6 Scope Change Control

Any feature not listed under MVP requires:

1. Product owner approval
2. Update to Feature List + Roadmap
3. Estimation impact on current phase

## 5.7 Definition of Done (Documentation Phase)

- All 30 markdown documents present under `Project_Documentation/`
- Design system extracted from provided brand/UI references
- Architecture supports Admin integration later
- Assumptions listed for validation
- No application source code generated in this phase
