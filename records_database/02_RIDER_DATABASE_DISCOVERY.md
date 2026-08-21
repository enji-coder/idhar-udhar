# RIDER APP — DATABASE DISCOVERY REPORT

**Scope:** `idhar_udhar/lib/rider/` plus shared `lib/shared/vehicle_category/`.  
**Method:** Code inspection only. No UI, schema, or dummy data changed.  
**Nature today:** Isolated Flutter demo (Riverpod + GoRouter). Data is dummy constants + in-memory `StateProvider`s + a few `SharedPreferences` flags. OTP is the literal demo code `123456`. No rider HTTP API except the same Admin vehicle-category GET used by Customer.

**Superseded for current-state (2026-08-21):** `FINAL_MASTER_ANALYSIS.md`. Keep this file as historical discovery. Rider UI now shows trip amount, customer/receiver payment, payment status, earning wallet vs COD Due. Login still skips OTP; one active-order slot.

---

## 1. Application Overview

**Entry:** `lib/rider/rider_main.dart` (separate from Customer `lib/main.dart`).

**State:** Riverpod (`Provider` / `StateProvider`). Repository: `DummyRiderRepository`.

**Local storage (`RiderPrefs`):** `rider_initial_setup_complete_v1`, `rider_terms_accepted_v1`, `rider_logged_in_v1`. Isolated from Customer `iu_*` keys. No profile/orders persisted.

**Permissions (`RiderPermissions`):** location when-in-use, camera, notifications, Android overlay (`systemAlertWindow`) for order alerts. No contacts / mic / SMS.

**Routes (`RiderRoutes`):**

| Path | Screen | Purpose |
|---|---|---|
| `/rider/splash` | RiderSplashScreen | Brand splash |
| `/rider/login` | RiderLoginScreen | Mobile login |
| `/rider/onboarding/terms` | RiderTermsScreen | Terms accept flag |
| `/rider/registration/welcome` | RegistrationWelcomeScreen | Benefits copy |
| `/rider/registration/mobile` | MobileVerificationScreen | 10-digit phone |
| `/rider/registration/otp` | OtpVerificationScreen | 6-digit dummy OTP |
| `/rider/registration/profile` | RiderProfileSetupScreen | Name, email, DOB, language, photo flag |
| `/rider/registration/vehicle-type` | VehicleTypeScreen | Category from Admin catalog |
| `/rider/registration/vehicle-details` | VehicleDetailsScreen | Number, model, color, year |
| `/rider/registration/driver-details` | RiderDriverDetailsScreen | Driver name, mobile, DOB, DL number |
| `/rider/registration/documents` | DocumentsScreen | Aadhaar/PAN/DL/RC/bank proof images |
| `/rider/registration/bank-upi` | RiderBankUpiScreen | Bank + UPI |
| `/rider/registration/verification` | VerificationStatusScreen | KYC timeline |
| `/rider/registration/permissions` | PermissionSetupScreen | OS permissions |
| `/rider/registration/complete` | RegistrationCompleteScreen | Done |
| `/rider/dashboard` | RiderDashboardScreen | Online toggle, stats, announcements |
| `/rider/orders/incoming` | IncomingOrderScreen | Offer + 27s timer, accept/reject |
| `/rider/orders/accepted` | (accept confirmation) | Post-accept |
| `/rider/orders/details` | OrderDetailsScreen | Active order details |
| `/rider/orders/active` | ActiveDeliveryScreen | Lifecycle status buttons |
| `/rider/profile` | RiderProfileScreen | Profile |
| `/rider/vehicle/edit` | VehicleDetailsScreen | Edit vehicle |
| `/rider/bank/edit` | RiderBankUpiScreen | Edit bank |
| `/rider/upi` | RiderUpiDetailsScreen | UPI display |
| `/rider/documents` | DocumentsScreen | Review docs |
| `/rider/wallet` | RiderWalletScreen | Balance |
| `/rider/income` | RiderIncomeScreen | Earnings / targets / incentives |
| `/rider/history` | RiderHistoryScreen | Delivery history statuses |
| `/rider/settings` | RiderSettingsScreen | Settings / logout |

---

## 2. Identified Entities

| Entity | Class | Purpose | Permanent? |
|---|---|---|---|
| Rider | `RiderProfile` | Identity | Yes |
| Driver details | `RiderDriverDetails` | License holder (often same as rider) | Yes |
| Vehicle | `VehicleInfo` | Rider’s vehicle | Yes |
| Vehicle type (legacy enum) | `RiderVehicleType` | bike / auto / miniTruck | Catalog overlap |
| Vehicle category | `VehicleCategory` (shared) | Admin master | Yes |
| Document | `RiderDocument` | KYC images | Yes |
| Bank / UPI | `RiderBankDetails` | Payout rails | Yes (sensitive) |
| Incoming / active order | `RiderOrder` | Offer + active job | Yes (order) |
| Delivery lifecycle | `DeliveryLifecycleStatus` | Rider-side status | Yes (order status) |
| History row | `RecentActivityItem` | Completed/rejected/cancelled | Yes |
| Earnings dashboard | `RiderEarnings` | Today/week/month + targets | Aggregates |
| Recent earning line | `RecentEarningItem` | Per-order earning | Ledger |
| Announcement | `RiderAnnouncement` | Company notices | Yes |
| Verification step | `VerificationStep` | KYC pipeline UI | Workflow |
| Online flag | `riderOnlineProvider` | Availability | Yes, high-churn |
| Wallet balance | `riderWalletBalanceProvider` | ₹2450 dummy | Yes |

**Not in Rider app:** proof of delivery capture, customer rating, invoice, commission %, operational cost, payout batch objects, live lat/lng model, chat, owner-vs-fleet company entity (driver details exist; no separate Owner model).

---

## 3. Field-level (production-relevant)

### RiderProfile
| Field | Type | Required | Example | Source |
|---|---|---|---|---|
| id | String | Yes | `rider_demo_001` | Dummy |
| name | String | Yes | Rahul Sharma | User |
| mobile | String | Yes | +91 98765 43210 | User |
| email | String | Yes in form | rahul.sharma@gmail.com | User |
| dateOfBirth | DateTime | Yes | 1997-08-12 | User |
| language | String | Yes | English | User (English/Hindi/Gujarati) |
| photoUrl | String? | No | — | Photo flag only (`_photoAdded`), no upload |
| rating | double | Yes | 4.8 | System/dummy |

### RiderDriverDetails
| Field | Type | Example |
|---|---|---|
| fullName | String | Rahul Sharma |
| mobile | String | same as rider dummy |
| dateOfBirthLabel | String | `12 Aug 1997` (display string, not DateTime) |
| licenseNumber | String | GJ05 20190012345 |

### VehicleInfo
| Field | Type | Example | Notes |
|---|---|---|---|
| type | RiderVehicleType | bike | Mapped from category name |
| number | String | GJ 05 AB 1234 | Registration |
| model | String | Honda Shine | |
| color | String | Black | |
| manufacturingYear | int | 2023 | |
| categoryName | String? | Bike | From Admin catalog; **name, not ID** |

`RiderVehicleType.fromLabel` maps: auto/three wheeler → auto; mini truck/tempo/large tempo/truck → miniTruck; else bike. **Name-based, lossy.**

### RiderDocument
| Field | Type | Notes |
|---|---|---|
| kind | enum | aadhaarFront/Back, panFront, dlFront/Back, rcFront/Back, bankProof |
| status | enum | uploadRequired, uploaded, pendingVerification, verified |
| fileName | String? | Dummy filenames |
| localPath | String? | Device path during registration |

No Aadhaar/PAN **numbers** stored—images only.

### RiderBankDetails
| Field | Type | Example |
|---|---|---|
| bankName | String | HDFC Bank |
| accountHolder | String | Rahul Sharma |
| accountNumber | String | 5010001233210 (masked in UI) |
| ifsc | String | HDFC0001234 |
| upiId | String | rahul.sharma@okhdfc |
| upiVerified | bool | true |
| proofUploaded | bool | true |

### RiderOrder (offer / active)
| Field | Type | Example |
|---|---|---|
| id | String | IU10248 |
| pickup | String | Ahmedabad One Mall (**string, not structured address**) |
| drop | String | Satellite, Ahmedabad |
| distanceKm | double | 7.8 |
| estimatedEarnings | double | 186 |
| estimatedMinutes | int | 24 |
| paymentMethod | cash \| online | online |
| customerMaskedName | String | Priya K. |
| customerMaskedPhone | String | +91 ******3210 |
| decisionSeconds | int | 27 |

No customerId, no vehicle_category_id, no fare snapshot, no COD vs online mapped to Admin payment modes.

### DeliveryLifecycleStatus
`accepted` → `goingToPickup` → `arrivedAtPickup` → `packagePickedUp` → `goingToDrop` → `delivered`

Advanced by rider buttons on Active Delivery. **No Failed, no Cancelled, no nearDestination.**

### History statuses (strings on `RecentActivityItem.status`)
`Accepted`, `Rejected by Rider`, `Rejected by Client`, `Cancelled`, `Completed`

These are **not** the same enum as `DeliveryLifecycleStatus`.

### RiderEarnings
todayAmount, yesterdayChangePercent, completedOrders, onlineDuration, targetOrders/Goal, targetAmount/Goal, incentiveProgress/Goal, recentEarnings[], weeklyDeliveries/Earnings, monthlyDeliveries/Earnings.

### RiderAnnouncement
kind (incentive/referral/bonus/weekend/opportunity/update/policy), title, body, badge, dateLabel.

---

## 4. Dummy / hardcoded data

- OTP `123456` (6 digits; Customer is 4 digits / any code)
- Profile Rahul Sharma, wallet ₹2450
- Vehicle Honda Shine GJ 05 AB 1234 (differs from Admin Vikram Singh GJ 01 RX 2145)
- Incoming order IU10248 ₹186 online, 27s
- History mix of Accepted / Rejected by Rider / Rejected by Client / Cancelled / Completed
- Online defaults **false**
- Vehicle catalog: shared Admin GET + fallback Bike/Auto/Mini Truck/Tempo/Large Tempo/Truck

---

## 5. Rider order flow (actual)

```text
Login / OTP (123456)
 → Terms, profile, vehicle type (Admin names), vehicle details
 → Driver details, documents (local files), bank/UPI
 → Verification timeline (dummy)
 → Permissions
 → Dashboard (offline until toggle)
 → Incoming offer (timer)
    → Reject / timeout  → history “Rejected by Rider” (UI only; no backend)
    → Accept → Active delivery status machine → Delivered
```

No dispatch algorithm, no location stream, no POD, no earning credit on deliver, no commission snapshot.

---

## 6. Statuses used by Rider

| Status | Where | Who changes |
|---|---|---|
| Offer timer running / expired | Incoming | Client timer |
| Reject | Incoming | Rider |
| accepted … delivered | Active delivery | Rider taps |
| History string statuses | History list | Dummy seed |

---

## 7. Financial fields visible to rider

- `estimatedEarnings` on offer (gross rider view, not 85% explained)
- Wallet balance dummy
- Income screen: today/week/month, incentives, targets
- No company commission, opex, profit, payout entity, cash-in-hand vs online split (Admin `riderWallet.js` has that; Rider app does not)

---

## 8. Real-time implied

- Incoming offer + countdown (must be push/socket in production)
- Online/offline
- Delivery status steps
- Overlay order alert permission
- Location for tracking (permission exists; no location model)

---

## 9. Files / images

- Profile photo: boolean only
- Documents: camera/file picker local paths
- No POD, no invoice PDF

---

## 10. Inconsistencies vs Customer / Admin

1. OTP length 6 vs Customer 4.  
2. Order IDs `IU10248` vs Customer `IU-2048` vs Admin `IU-AMD-10421`.  
3. Vehicle type enum collapses Tempo/Truck into miniTruck.  
4. Category joined by **name**.  
5. Delivery status vocabulary differs from Customer and Admin.  
6. Customer sees full rider phone; Rider sees masked customer.  
7. No shared order object.  
8. Dummy rider identity ≠ Admin fleet dummy riders.

---

## 11. Recommended production entities (from Rider screens)

Rider, RiderDriver (if owner≠driver), RiderVehicle, RiderDocument, RiderBankAccount, RiderUpi, RiderAvailability, RiderLocation (time-series, not fat row), OrderOffer, Order (shared), Wallet, WalletTransaction, EarningsLedger, AnnouncementReceipt, VerificationCase.

**Do not implement in this step.**
