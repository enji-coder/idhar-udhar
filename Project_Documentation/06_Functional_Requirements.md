# 06 — Functional Requirements

## 6.1 Conventions

- **FR-C-xxx** — Customer App
- **FR-R-xxx** — Rider App
- **FR-S-xxx** — Shared / System
- **FR-A-xxx** — Admin (future; architectural constraints)

Priority: Must / Should / Could (MoSCoW for MVP focus on Must).

---

## 6.2 Customer — Authentication

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-C-001 | User can register with full name, mobile (+91), email, password, and accept T&Cs | Must |
| FR-C-002 | System sends OTP to mobile for verification after registration or sensitive actions | Must |
| FR-C-003 | User can log in with mobile + password | Must |
| FR-C-004 | User can enable “Remember me” to persist session securely | Must |
| FR-C-005 | User can request forgot password; receive OTP; set new password | Must |
| FR-C-006 | Invalid credentials show clear, non-leaking error messages | Must |
| FR-C-007 | Social login (Google/Apple) available | Should (V1.1) |

## 6.3 Customer — Onboarding & Permissions

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-C-010 | First launch shows splash then optional 3-screen onboarding | Must |
| FR-C-011 | User can Skip onboarding | Must |
| FR-C-012 | App presents location permission rationale screen before system dialog | Must |
| FR-C-013 | If location denied, user can continue with limited functionality and re-prompt from booking | Must |

## 6.4 Customer — Booking Funnel

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-C-020 | User selects pickup location via map pin and/or Places autocomplete | Must |
| FR-C-021 | User selects drop location similarly | Must |
| FR-C-022 | System validates pickup ≠ drop and both in serviceable area | Must |
| FR-C-023 | User selects parcel type from configured catalog | Must |
| FR-C-024 | User enters parcel details (notes; optional photos) | Should |
| FR-C-025 | User selects weight slab | Must |
| FR-C-026 | User selects vehicle category; UI highlights selected card | Must |
| FR-C-027 | System computes fare estimate using distance, vehicle, weight, and city rules | Must |
| FR-C-028 | User can apply a valid coupon; fare updates | Must |
| FR-C-029 | User confirms booking; booking enters `searching` state | Must |
| FR-C-030 | User receives push when rider assigned / arrives / completes | Must |

## 6.5 Customer — Live Trip

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-C-040 | Active trip shows live rider location on map | Must |
| FR-C-041 | UI shows rider name, vehicle number, rating, ETA | Must |
| FR-C-042 | User can cancel per cancellation policy; fee may apply | Must |
| FR-C-043 | User can rate rider 1–5 with optional comment after completion | Must |

## 6.6 Customer — Payments & History

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-C-050 | Fare breakdown shows base, distance, weight, discounts, taxes (if any) | Must |
| FR-C-051 | Cash payment supported at trip end | Must |
| FR-C-052 | Online payment gateway integration | Should (V1.1) |
| FR-C-053 | User can view paginated order history and open trip detail | Must |

## 6.7 Customer — Account

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-C-060 | User can view/edit profile fields | Must |
| FR-C-061 | User can open Help & Support (FAQ + create ticket) | Must |
| FR-C-062 | User can log out | Must |
| FR-C-063 | User can request account deletion | Must |

---

## 6.8 Rider — Authentication & KYC

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-R-001 | Rider registers/logs in similarly to customer (role claim differs) | Must |
| FR-R-002 | Rider uploads required documents to Storage; metadata in Firestore | Must |
| FR-R-003 | Rider registers vehicle type, plate, and photos | Must |
| FR-R-004 | Rider cannot go Online until KYC status is `approved` | Must |
| FR-R-005 | Rider sees KYC pending/rejected reasons | Must |

## 6.9 Rider — Jobs

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-R-010 | Rider toggles Online/Offline; location streamed when online | Must |
| FR-R-011 | Nearby booking requests appear with fare, distance, parcel summary | Must |
| FR-R-012 | Rider can Accept or Reject within timeout | Must |
| FR-R-013 | On Accept, trip binds to rider; customer notified | Must |
| FR-R-014 | Rider opens navigation to pickup then drop | Must |
| FR-R-015 | Rider confirms pickup (OTP or confirmation code) | Must |
| FR-R-016 | Rider confirms delivery (OTP / photo proof) | Must |

## 6.10 Rider — Earnings

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-R-020 | Earnings dashboard shows today/week/month totals | Must |
| FR-R-021 | Wallet shows balance and payout history | Must |
| FR-R-022 | Trip history lists completed/cancelled jobs | Must |
| FR-R-023 | Ratings aggregate displayed on profile | Must |

---

## 6.11 Shared System Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-S-001 | Auth tokens stored in secure storage | Must |
| FR-S-002 | FCM tokens registered per device/user | Must |
| FR-S-003 | Crash reports sent to Crashlytics | Must |
| FR-S-004 | Booking status machine enforced server-side (Cloud Functions / rules) | Must |
| FR-S-005 | Soft delete / anonymization path documented for GDPR-like requests | Should |

## 6.12 Admin Architectural Requirements (Future)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-A-001 | All core collections queryable by `cityId`, `status`, time range | Must (schema now) |
| FR-A-002 | Custom claims support `admin` / `ops` roles | Must (design now) |
| FR-A-003 | Coupon, vehicle, and fare configs are data-driven (not hardcoded) | Must |
