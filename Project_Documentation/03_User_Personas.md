# 03 — User Personas

## 3.1 Persona Overview

| ID | Persona | Primary App | Core Job-to-be-Done |
|----|---------|-------------|---------------------|
| P1 | Priya — Urban Customer | Customer App | Move a parcel same-day without hassle |
| P2 | Ravi — Shop Owner | Customer App | Regular business dispatches with predictable cost |
| P3 | Arjun — Full-time Rider | Rider App | Maximize daily earnings with clear jobs |
| P4 | Meena — Part-time Rider | Rider App | Flexible hours; simple accept/earn flow |
| P5 | Ops Lead — Admin (future) | Admin Panel | Keep marketplace healthy and fair |

---

## 3.2 P1 — Priya Sharma (Urban Customer)

| Attribute | Detail |
|-----------|--------|
| Age | 28 |
| Location | Bengaluru |
| Occupation | Marketing professional |
| Tech comfort | High (daily smartphone apps) |
| Frequency | 1–4 bookings / month |

### Goals

- Send gifts, documents, or electronics across the city quickly
- See fare upfront; pay with UPI
- Track the rider live and share status with the recipient

### Pain Points

- Opaque pricing from local transporters
- No tracking once the vehicle leaves
- Fear of damage / unprofessional handlers

### Needs from IDHAR UDHAR

- Glass-clear booking in < 3 minutes
- Vehicle recommendations by parcel type/weight
- Live map + OTP / confirmation at pickup & drop
- Help & support with ticket trail

### Design Implications

- Emphasize trust badges, OTP security, and mixed navy/orange headlines
- Onboarding should sell “Anything, Anytime, Anywhere”

---

## 3.3 P2 — Ravi Patel (SMB Shop Owner)

| Attribute | Detail |
|-----------|--------|
| Age | 42 |
| Location | Ahmedabad |
| Occupation | Electronics retailer |
| Tech comfort | Medium |
| Frequency | 5–20 bookings / week |

### Goals

- Dispatch inventory to customers and other shops
- Keep costs predictable; reuse addresses
- Maintain GST-friendly payment records (future)

### Pain Points

- Calling drivers repeatedly
- No consolidated history for accounting
- Peak-hour unavailability

### Needs from IDHAR UDHAR

- Saved addresses & favorite vehicles
- Order history with fare breakdown
- Coupons / business offers
- Reliable supply of pickups near market areas

### Design Implications

- Fast rebooking from history
- Clear fare estimate and coupon flows
- Profile & settings must feel “business capable”

---

## 3.4 P3 — Arjun Singh (Full-time Rider)

| Attribute | Detail |
|-----------|--------|
| Age | 31 |
| Location | Delhi NCR |
| Vehicle | Pickup / mini truck |
| Tech comfort | Medium–High |
| Motivation | Primary income |

### Goals

- Stay online and receive high-value nearby jobs
- Navigate efficiently; complete more trips/day
- Track earnings, wallet balance, and incentives

### Pain Points

- Fake or low-fare requests
- Unclear pickup points
- Delayed payouts / opaque deductions

### Needs from IDHAR UDHAR

- Strong Online/Offline toggle
- Accept/Reject with enough context (fare, distance, parcel)
- Google Navigation deep link / in-app nav
- Transparent earnings & trip history
- Smooth KYC & vehicle registration

### Design Implications

- Large tap targets; high-contrast CTAs for Accept
- Earnings dashboard as a first-class home module
- Clear document verification status states

---

## 3.5 P4 — Meena Devi (Part-time Rider)

| Attribute | Detail |
|-----------|--------|
| Age | 26 |
| Location | Pune |
| Vehicle | Bike / scooter |
| Tech comfort | Medium |
| Motivation | Supplemental income |

### Goals

- Work evenings / weekends only
- Prefer smaller parcels (documents, gifts)
- Simple flow: go online → accept → deliver → earn

### Pain Points

- Complex apps with too many screens
- Strict penalties for occasional rejects
- Difficulty understanding document upload requirements

### Needs from IDHAR UDHAR

- Guided KYC with clear examples
- Soft availability without pressure
- Notifications that respect quiet hours (settings)
- Ratings that don’t feel punitive for first months

### Design Implications

- Progressive onboarding for riders
- Plain-language verification screens
- Notification preferences in profile

---

## 3.6 P5 — Ops Lead (Admin — Future)

| Attribute | Detail |
|-----------|--------|
| Role | City / regional operations |
| Tools | Future Admin Panel + Firebase console interim |

### Goals

- Monitor live bookings and supply gaps
- Suspend fraudulent accounts
- Configure offers and vehicle categories
- Export reports for finance

### Design Implications (Architecture Only Now)

- Every entity needs `status`, `createdAt`, `updatedAt`, `cityId`
- Audit logs for critical mutations
- Role-based claims for admin later

---

## 3.7 Anti-Personas (Not Primary Targets Initially)

- International shipping customers
- Warehouse-to-warehouse freight brokers
- Unverified cash-only informal drivers (must pass KYC)

## 3.8 Accessibility & Inclusion Notes

- Support large system font scales
- Color contrast: orange on white / navy on cream must meet WCAG AA where possible
- Hindi localization planned (see Future Enhancements); English-first MVP
- Voice-over friendly labels on primary CTAs
