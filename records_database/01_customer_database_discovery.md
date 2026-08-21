# CUSTOMER APP — DATABASE DISCOVERY REPORT

**Scope:** `idhar_udhar` Flutter Customer App (`lib/customer/` + shared `lib/shared/vehicle_category/`).  
**Method:** Code inspection only. No files created, no schema implemented, no dummy data changed.  
**Nature of the app today:** A Riverpod + GoRouter **UI demo**. Almost all data is in-memory or `SharedPreferences`. There is **no Firebase**, **no customer API client**, **no repositories**, and **no PostgreSQL**. The only live HTTP call is Admin vehicle-category catalog fetch.

**Superseded for current-state (2026-08-21 alignment):** `FINAL_MASTER_ANALYSIS.md`. Keep this file as historical discovery. **FINAL payment rule:** split who-pays / how-they-pay is supported; this discovery’s “no payment step” notes are outdated.

---

## 1. Application Overview

**Product:** IDHAR UDHAR customer mobile app — book a parcel delivery from pickup to drop, choose a vehicle family, enter parcel details, see an estimated fare, confirm a booking, watch a demo rider-assignment/tracking flow, then view orders and a demo wallet.

**Entry:** `lib/main.dart` launches `lib/customer/customer_main.dart`. Environment is hardcoded to `AppEnvironment.development`.

**State management:** Flutter Riverpod (`StateNotifierProvider`). No Bloc, no GetX usage in customer code.

**Navigation (GoRouter):**

| Route | Screen | Purpose |
|---|---|---|
| `/splash` | SplashScreen | Brand splash, hydrate local session |
| `/login` | LoginScreen | 10-digit phone |
| `/otp` | OtpVerificationScreen | 4-digit dummy OTP |
| `/profile-setup` | ProfileSetupScreen | First-time name |
| `/location-permission` | LocationPermissionScreen | OS location permission |
| `/home/dashboard` | DashboardScreen | Home / book CTA / services |
| `/home/orders` | OrdersScreen | Order list + filters |
| `/home/wallet` | WalletScreen | Balance + dummy txns |
| `/home/profile` | ProfileScreen | Profile menu |
| `/book/pickup` | PickupLocationScreen | Pickup address |
| `/book/drop` | DropLocationScreen | Drop address |
| `/book/vehicle` | VehicleSelectionScreen | Vehicle choice |
| `/book/package` | PackageDetailsScreen | Parcel details |
| `/book/summary` | BookingSummaryScreen | Confirm booking |
| `/book/searching` | SearchingRiderScreen | Demo rider search |
| `/book/rider-assigned` | RiderAssignedScreen | Assigned rider |
| `/book/tracking` | TrackingScreen | Demo status timeline |
| `/book/completed` | DeliveryCompletedScreen | Completion + invoice copy |
| `/orders/:id` | OrderDetailsScreen | Order detail |
| `/profile/edit` | EditProfileScreen | Name + invoicing email |
| `/profile/saved-addresses` | SavedAddressesScreen | Address book CRUD |
| `/help` | HelpScreen | Static FAQ titles |

**Home tabs:** Home, Orders, Wallet, Profile.

**Auth:** Phone + dummy OTP (any 4 digits). Session persisted locally. No tokens, no SMS gateway.

**Backend today:**
- Placeholder API bases in `AppConfig` (`dev-api.idharudhar.local`, `staging-api.idharudhar.in`, `api.idharudhar.in`) — unused by customer screens.
- Firebase is a placeholder file only (`config/firebase/firebase_placeholder.dart`).
- One live GET: `VehicleCategoryCatalog` → Admin Netlify function `vehicle-categories`.

**Local storage actually used:** `SharedPreferences` for session, known names/emails by phone, and saved addresses.  
**Declared but unused in customer code:** Hive (`hiveBoxApp` constant only), `flutter_secure_storage` (prefix constant only), `image_picker`, `file_picker`.

**Features present in UI:** login/OTP, profile name/email, location permission, saved addresses, booking flow, fare estimate, cancel before accept, demo tracking, order history filters, wallet UI, help titles, invite banner, notification **icon**, decorative rating stars, invoice **copy**.

**Features not implemented (no model, no screen logic, or empty tap):** real OTP, payments, promo codes, notification inbox, proof of delivery, parcel photos, profile photo, live maps/GPS, chat, call, tickets, invoice PDF, refunds, failed delivery, scheduled booking UI, referral codes.

---

## 2. All Identified Entities

Derived from customer models and screens. Placeholder-only UI (empty taps, no fields) is noted, not treated as a full entity.

| Entity | Purpose | Existing class | Where used | Permanent / temporary |
|---|---|---|---|---|
| **Customer** | Authenticated booker | `MockUser` | Login, OTP, profile, session, invoice email prompt | Permanent (intended); locally persisted |
| **Session** | Local login restore | `PersistedSession` / `SessionState` | Splash hydrate, logout | Temporary device cache of customer |
| **Address** | Pickup, drop, saved book | `MockLocation` | Pickup/drop, saved addresses, orders | Permanent if saved; booking copy is order snapshot |
| **Address label** | Home / Office / Friend / Other | `AddressLabel` | Saved address editor | Lookup / enum |
| **Vehicle option** | Bookable vehicle shown to customer | `MockVehicle` | Vehicle selection, summary, orders | Catalog (master) |
| **Vehicle category** | Admin-managed availability | `VehicleCategory` | Filters customer vehicle list | Catalog (master, remote) |
| **Service family** | Home booking filter | `ServiceFamily` | Dashboard → vehicle screen | UI filter, not stored on order |
| **Parcel category** | What is being sent | `MockParcelCategory` | Package details | Catalog; copied onto order as label |
| **Parcel size** | Size band | `MockParcelSize` | Package details | Catalog; **not copied onto order** |
| **Booking draft / parcel details** | In-progress booking | `BookingDraft` | Entire book flow | Temporary; lost on `reset()` |
| **Order** | Confirmed delivery job | `MockOrder` | Confirm → tracking → history | Permanent (intended); **memory only** |
| **Order status** | Delivery lifecycle | `OrderStatus` | Order, tracking, filters | Permanent on order |
| **Rider (customer view)** | Assigned delivery partner | `MockRider` | Assigned, tracking, completed | Permanent snapshot on order |
| **Fare breakdown** | Estimated price lines | `FareBreakdown` | Summary, package price | Calculated; **not stored on order** |
| **Wallet** | Customer prepaid balance | `SessionState.walletBalance` (no class) | Wallet screen | Permanent (intended); **not persisted** |
| **Wallet transaction** | Wallet ledger line | `MockWalletTxn` | Wallet screen | Permanent (intended); hardcoded list |
| **Wallet payment method** | Future top-up rails | `WalletPaymentOption` | Wallet “Add Money” | Catalog / UI only |
| **Invoice (flags only)** | “Invoice sent to email” | fields on `MockOrder` | Completed, order details | Intended permanent; no invoice object |
| **Help topic** | Static FAQ rows | none (inline tuples) | Help screen | Content, not user data |
| **Notification** | Badge + empty menu | **no model** | Dashboard badge, Profile tile | UI placeholder only |
| **Referral / invite** | Banner “₹200 wallet” | **no model** | Dashboard | UI placeholder only |
| **Customer rating of delivery** | Star row on completed | **no model** | Delivery completed | Decorative only |

**Relationships (conceptual):**
- Customer 1—* Addresses  
- Customer 1—* Orders  
- Customer 1—1 Wallet  
- Wallet 1—* Wallet transactions  
- Order *—1 Pickup address snapshot, *—1 Drop address snapshot  
- Order *—1 Vehicle snapshot  
- Order *—0..1 Rider snapshot  
- Order has status, fare total, optional invoice flags  
- BookingDraft *temporarily* holds parcel extras (size, fragile, COD, instructions) before confirm

---

## 3. Detailed Entity Fields

| Entity | Field | Type | Required? | Example | Source | Used By | Notes |
|---|---|---|---|---|---|---|---|
| Customer | id | String | Yes | `u_123456` | System (`u_${phone.hashCode.abs()}`) | Session persist | Not a UUID; hash of phone |
| Customer | phone | String | Yes | `+919876543210` | User (`+91` + 10 digits) | Login, profile, session | Immutable in Edit Profile |
| Customer | name | String | Yes after setup | `Anjali` | User | Profile setup, edit, dashboard greeting | Min 2 chars, max 40; letters/spaces/`'.-` |
| Customer | email | String | Optional in profile; **required to continue after rider assigned** if empty | `name@example.com` | User | Edit profile, rider-assigned prompt, invoice | “For invoicing”; optional until Track Delivery |
| Session | authenticated | bool | Yes | `true` | System | SessionStorage | Local flag, not a token |
| Session | isHydrated | bool | Yes | `true` | System | Splash | UI-only restore guard |
| Address | id | String | Yes | `loc_home` / `loc_1710…` | System | Saved addresses, booking | Seed IDs or `loc_{ms}` |
| Address | label | String | Yes | `Home` | User (from `AddressLabel.title`) | Lists, order route text | Duplicates `addressLabel` |
| Address | address | String | Yes | `12, Satellite Road, Ahmedabad` | User | Pickup/drop/orders | Min 5 chars on save |
| Address | city | String | Optional | `Ahmedabad` | User; default `Ahmedabad` | Editor | Not shown on most booking rows |
| Address | isSaved | bool | Yes in book | `true` | System | Saved vs catalog mix | Seed “current location” is not saved |
| Address | iconName | String | No | `home` | System from label | Pickup icons | `home`/`work`/`friend`/`place`/`my_location`/`warehouse` |
| Address | landmark | String | Optional | `Near ISRO` | User | Saved list | |
| Address | latitude | double? | Optional | `23.0225` | Seed only; **not collected in editor** | Unused on map | No live GPS write |
| Address | longitude | double? | Optional | `72.5714` | Seed only | Unused on map | |
| Address | addressLabel | AddressLabel? | Optional | `home` | User chip | Saved addresses | `home`/`office`/`friend`/`other` |
| Address | createdAt | DateTime? | On save | ISO timestamp | System | Persistence JSON | |
| Address | updatedAt | DateTime? | On save | ISO timestamp | System | Persistence JSON | |
| Vehicle | id | String | Yes | `v_bike` | Hardcoded / `v_{categoryId}` | Selection | |
| Vehicle | type | VehicleType | Yes | `bike` | Hardcoded / inferred | Family filter | `bike,scooty,auto,car,truck,pickup` |
| Vehicle | name | String | Yes | `Bike` | Hardcoded / admin name | UI | |
| Vehicle | description | String | Yes | `Documents & small parcels` | Hardcoded | Vehicle card | Synthesized: `Admin-managed vehicle type` |
| Vehicle | capacity | String | Yes | `Up to 20 kg` | Hardcoded text | Vehicle card | Not numeric |
| Vehicle | etaMinutes | int | Yes | `12` | Hardcoded | Vehicle, summary | Not live ETA |
| Vehicle | baseFare | double | Yes | `79` | Hardcoded | Fare calc | Synthesized 79/149/499 |
| Vehicle | imagePath | String | Yes | asset path | Hardcoded | Cards | Local asset, not URL |
| VehicleCategory | id | String | Yes | `VC-1001` | Admin API / fallback | Catalog filter | |
| VehicleCategory | name | String | Yes | `Bike` | Admin API | Match MockVehicle | Name matching is fragile |
| VehicleCategory | status | String | Yes | `Active` | Admin API | `isActive` | String, not enum |
| VehicleCategory | available | bool | Yes | `true` | Admin API | Selectable list | Mini Truck/Tempo fallback `false` |
| ParcelCategory | id | String | Yes | `c_docs` | Hardcoded | Draft `categoryId` | Default draft `c_pkg` |
| ParcelCategory | label | String | Yes | `Documents` | Hardcoded | Summary as package name | Copied to `MockOrder.packageLabel` |
| ParcelCategory | imagePath | String | Yes | parcel asset | Hardcoded | Grid | |
| ParcelCategory | icon | String | Yes | `description` | Hardcoded | Unused in screen (images used) | Material icon name string |
| ParcelSize | id | String | Yes | `s_md` | Hardcoded | Draft `sizeId` | Default `s_md` |
| ParcelSize | label | String | Yes | `Medium` | Hardcoded | Summary | **Not stored on MockOrder** |
| ParcelSize | subtitle | String | Yes | `Up to 60 cm` | Hardcoded | Size chips | Small 30 / Med 60 / Large 90 / XL above 90 |
| ParcelSize | imagePath | String | Yes | asset | Hardcoded | Size chips | |
| BookingDraft | pickup | MockLocation? | Yes to continue | Current Location seed | User | Book flow | Defaults to `MockData.locations[4]` |
| BookingDraft | drop | MockLocation? | Yes to continue | Vesu | User | Book flow | Cannot equal pickup id |
| BookingDraft | vehicle | MockVehicle? | Yes to continue | Bike | User | Book flow | Auto-set if family has 1 option |
| BookingDraft | serviceFamily | ServiceFamily? | No | `twoWheeler` | User (home tiles) | Vehicle filter | Cleared on generic Book CTA |
| BookingDraft | categoryId | String | Yes (defaulted) | `c_pkg` | User | Package screen | |
| BookingDraft | sizeId | String | Yes (defaulted) | `s_md` | User | Package screen | Dropped at confirm |
| BookingDraft | weightKg | double | Yes | `5` | User | Fare + order | Presets 0.5/1/2/5/10 or custom; clamp 0.5–1000 |
| BookingDraft | instructions | String | No | `Call on arrival` | User | Summary if non-empty; copied to order | UI counter `/120`; no hard max formatter |
| BookingDraft | fragile | bool | Yes (default false) | `true` | User | Fare vehicleCharge 30 vs 15 | **Not copied to MockOrder** |
| BookingDraft | cod | bool | Yes (default false) | `true` | User | Package toggle only | **Not copied to MockOrder; no payment effect** |
| BookingDraft | scheduledAt | DateTime? | No | — | API exists, **no UI caller** | Would copy to order | Dead field |
| BookingDraft | activeOrder | MockOrder? | During live booking | IU-2048 | System | Searching→completed | Cleared on `reset()` |
| Order | id | String | Yes | `IU-2048` | System `IU-{ms % 100000}` | All order UIs | Collision-prone |
| Order | status | OrderStatus | Yes | `inTransit` | System (demo timers/buttons) | Tracking, lists | See §7 |
| Order | pickup | MockLocation | Yes | nested address | From draft | Details, tracking | Full object nested |
| Order | drop | MockLocation | Yes | nested address | From draft | Details, tracking | |
| Order | vehicle | MockVehicle | Yes | nested vehicle | From draft | Details, fare display | Full object nested |
| Order | fare | double | Yes | `149` | Calculated `estimatedFare` at confirm | Lists, details | Single total; breakdown discarded |
| Order | createdAt | DateTime | Yes | now | System | Order details date | |
| Order | rider | MockRider? | After assign | Aarav Patel | System dummy | Assigned/tracking | Always `demoRider` |
| Order | packageLabel | String | Yes | `Documents` | From category label | Details | Size not included |
| Order | weightKg | double | Yes | `2` | From draft | Details | |
| Order | instructions | String | No | `Handle with care` | From draft | **Not shown on order details** | Stored but unused in details UI |
| Order | etaMinutes | int | Yes | `18` | Copied then patched per status | Tracking | Demo, not GPS |
| Order | scheduledAt | DateTime? | No | — | From draft | Nowhere in UI | Dead |
| Order | invoiceSent | bool | Yes (default false) | `true` | Set on `markDelivered` if email non-empty | Orders list, details | No email send |
| Order | invoiceEmail | String | No | `customer@example.com` | Profile email at deliver | Completed, details | |
| Order | canCancel | bool (getter) | — | true if searching/assigned | Calculated | Searching, assigned, tracking | See §7 |
| Rider | id | String | Yes | `r_01` | Hardcoded | Nested on order | Single demo rider |
| Rider | name | String | Yes | `Aarav Patel` | Hardcoded | Cards | |
| Rider | vehicleLabel | String | Yes | `Bike • GJ-01-AB-2345` | Hardcoded | Cards | Plate embedded in string |
| Rider | rating | double | Yes | `4.8` | Hardcoded | RiderCard | Rider’s rating, not customer review |
| Rider | phone | String | Yes | `+919800011122` | Hardcoded | **Not displayed**; Call button empty | |
| Rider | trips | int | No | `842` | Hardcoded | Assigned subtitle | |
| Rider | imagePath | String? | No | rider asset | Hardcoded | Screens use `AssetPaths.rider` anyway | `RiderCard.avatarUrl` unused |
| FareBreakdown | baseFare | double | Yes | `79` | Vehicle.baseFare or 99 | Summary | |
| FareBreakdown | distanceCharge | double | Yes | `20` | **`weightKg * 4` clamped 20–400** | Summary | Name says distance; formula is weight |
| FareBreakdown | vehicleCharge | double | Yes | `15` or `30` | Fragile flag | Summary | |
| FareBreakdown | platformFee | double | Yes | `10` | Hardcoded | Summary | |
| FareBreakdown | tax | double | Yes | 5% of subtotal | Calculated | Summary | Rate hardcoded 0.05 |
| FareBreakdown | total | double (getter) | Yes | sum | Calculated | Draft fare, order.fare | |
| Wallet | balance | double | Yes | `420` | Hardcoded in SessionState | Wallet screen | Reset to 420 on hydrate; `addWallet()` unused by UI |
| WalletTxn | id | String | Yes | `w1` | Hardcoded | Wallet list | |
| WalletTxn | title | String | Yes | `Delivery IU-1024` | Hardcoded | Wallet list | Not linked to `MockOrder` |
| WalletTxn | amount | double | Yes | `500` | Hardcoded | Wallet list | |
| WalletTxn | date | DateTime | Yes | now−1 day | Hardcoded relative | Wallet list | |
| WalletTxn | isCredit | bool | Yes | `true` | Hardcoded | Sign/color | No txn type enum |
| WalletPaymentOption | id | String | Yes | `pay_gpay` | Hardcoded | Wallet methods | Selection not persisted |
| WalletPaymentOption | kind | enum | Yes | `googlePay` | Hardcoded | Icon switch | |
| WalletPaymentOption | label | String | Yes | `Google Pay` | Hardcoded | UI | |
| WalletPaymentOption | group | String | Yes | `UPI` | Hardcoded | Group header | UPI / Net Banking / Card |

**Not present as fields anywhere:** payment method on order, payment status, transaction ID, refund, promo code, GSTIN, pickup contact name/phone, drop contact, parcel photo, POD photo/signature, OTP at delivery, chat messages, device tokens, notification records, customer-given star rating, cancel reason, failed-delivery reason, live lat/lng of rider.

---

## 4. Existing Models / Classes

```text
Model/Class: MockUser
File: lib/customer/core/data/mock/mock_models.dart
Purpose: Customer identity for dummy auth/profile
Fields: id, phone, name, email
Used by: SessionState, SessionStorage, Login/OTP/Profile/Edit Profile, RiderAssigned email prompt
Related models: PersistedSession, SessionState
Represents: intended database data; currently local/mock
```

```text
Model/Class: MockLocation
File: lib/customer/core/data/mock/mock_models.dart
Purpose: Address for saved book and booking pickup/drop
Fields: id, label, address, city, isSaved, iconName, landmark, latitude, longitude, addressLabel, createdAt, updatedAt
Used by: MockData, SavedAddressesNotifier, Pickup/Drop screens, nested in MockOrder
Related models: AddressLabel, MockOrder, BookingDraft
Represents: database data (saved) + booking snapshot; JSON persisted locally
```

```text
Model/Class: AddressLabel (enum)
File: mock_models.dart
Purpose: Saved-address category
Fields: home, office, friend, other (+ title, iconName)
Used by: SavedAddressesScreen editor, MockLocation
Related models: MockLocation
Represents: lookup / enum, not a table required but useful as constrained values
```

```text
Model/Class: MockVehicle
File: mock_models.dart
Purpose: Vehicle option + pricing seed for booking
Fields: id, type, name, description, capacity, etaMinutes, baseFare, imagePath
Used by: MockData, VehicleSelectionScreen, BookingDraft, MockOrder
Related models: VehicleType, VehicleCategory, FareBreakdown
Represents: catalog / database master data (partially duplicated with VehicleCategory)
```

```text
Model/Class: VehicleType (enum)
File: mock_models.dart
Purpose: Internal vehicle kind
Values: bike, scooty, auto, car, truck, pickup
Used by: MockVehicle, MockData.vehiclesForFamily
Related models: MockVehicle, ServiceFamily
Represents: catalog discriminator; inconsistent with admin catalog names
```

```text
Model/Class: ServiceFamily (enum)
File: mock_models.dart
Purpose: Home screen booking filter
Values: twoWheeler, threeWheeler, truck
Used by: DashboardScreen, BookingDraft, VehicleSelectionScreen
Related models: MockVehicle
Represents: UI-only state (not stored on order)
```

```text
Model/Class: VehicleCategory
File: lib/shared/vehicle_category/vehicle_category.dart
Purpose: Admin CRUD catalog consumed by customer + rider
Fields: id, name, status, available
Used by: VehicleCategoryCatalog, MockData.vehiclesForFamily, VehicleSelectionScreen
Related models: MockVehicle
Represents: API response / database catalog (only live backend entity)
```

```text
Model/Class: MockRider
File: mock_models.dart
Purpose: Assigned rider shown to customer
Fields: id, name, vehicleLabel, rating, phone, trips, imagePath
Used by: MockData.demoRider, MockOrder.rider, RiderAssignedScreen, TrackingScreen
Related models: MockOrder
Represents: intended database data; currently a single hardcoded record
```

```text
Model/Class: FareBreakdown
File: mock_models.dart
Purpose: Dummy invoice/pricing lines
Fields: baseFare, distanceCharge, vehicleCharge, platformFee, tax; getter total
Used by: BookingDraft.fareBreakdown, BookingSummaryScreen, PackageDetails estimated price
Related models: BookingDraft, MockOrder.fare
Represents: calculated data; not persisted
```

```text
Model/Class: MockOrder
File: mock_models.dart
Purpose: Confirmed booking / history item
Fields: id, status, pickup, drop, vehicle, fare, createdAt, rider, packageLabel, weightKg, instructions, etaMinutes, scheduledAt, invoiceSent, invoiceEmail
Used by: SessionState.orders, BookingDraft.activeOrder, Orders/Details/Tracking/Completed/Dashboard
Related models: MockLocation, MockVehicle, MockRider, OrderStatus
Represents: intended database data; currently in-memory mock
```

```text
Model/Class: OrderStatus (enum)
File: mock_models.dart
Purpose: Delivery lifecycle
Values: searching, assigned, accepted, arriving, pickup, inTransit, nearDestination, delivered, cancelled
Used by: MockOrder, TrackingScreen, OrdersScreen filters, BookingDraftNotifier
Related models: MockOrder
Represents: database status enum
```

```text
Model/Class: MockParcelCategory
File: mock_models.dart
Purpose: Parcel type catalog
Fields: id, label, imagePath, icon
Used by: MockData, PackageDetailsScreen, BookingDraft.categoryLabel
Related models: BookingDraft, MockOrder.packageLabel
Represents: catalog / lookup
```

```text
Model/Class: MockParcelSize
File: mock_models.dart
Purpose: Parcel size catalog
Fields: id, label, subtitle, imagePath
Used by: MockData, PackageDetailsScreen, BookingDraft.sizeLabel
Related models: BookingDraft (not MockOrder)
Represents: catalog / lookup; dropped at order persist
```

```text
Model/Class: BookingDraft
File: lib/customer/core/state/booking_draft_provider.dart
Purpose: Multi-step booking form state
Fields: pickup, drop, vehicle, serviceFamily, categoryId, sizeId, weightKg, instructions, fragile, cod, activeOrder, scheduledAt
Used by: All /book/* screens
Related models: MockLocation, MockVehicle, MockOrder, FareBreakdown
Represents: temporary form data
```

```text
Model/Class: SessionState / SessionNotifier
File: lib/customer/core/state/session_provider.dart
Purpose: Auth + in-memory orders + wallet
Fields: user, isAuthenticated, walletBalance, orders, isHydrated
Used by: Almost all feature screens
Related models: MockUser, MockOrder
Represents: mixed: auth session + UI cache of orders/wallet
```

```text
Model/Class: PersistedSession
File: lib/customer/core/storage/session_storage.dart
Purpose: JSON blob for login restore
Fields: user (id, phone, name, email, authenticated)
Used by: SessionNotifier.hydrate/save
Related models: MockUser
Represents: local cache, not server session
```

```text
Model/Class: SavedAddressesState / SavedAddressesNotifier
File: lib/customer/core/state/saved_addresses_provider.dart
Purpose: Local address book CRUD
Fields: addresses, isLoading, error
Used by: SavedAddressesScreen, Pickup/Drop
Related models: MockLocation
Represents: intended database data; currently device JSON list (not user-scoped)
```

```text
Model/Class: WalletPaymentMethodKind / WalletPaymentOption
File: mock_models.dart
Purpose: Future wallet top-up methods
Fields: id, kind, label, group
Used by: WalletScreen
Related models: none wired to payments
Represents: catalog / UI-only; no charges
```

```text
Model/Class: MockWalletTxn
File: mock_models.dart
Purpose: Dummy wallet ledger
Fields: id, title, amount, date, isCredit
Used by: WalletScreen
Related models: none (not linked to orders or balance)
Represents: intended database ledger; currently hardcoded
```

**UI-only / not data models:** screen widgets, theme classes, `AppCopy`, `AssetPaths`, `AppConfig`, `AppConstants`, `Environment`, `LocationPermissionService`, `RiderCard`/`BookingCard`/`ParcelCard` (widgets; BookingCard/ParcelCard unused by screens).

---

## 5. Dummy / Hardcoded Data

```text
Location: lib/customer/core/data/mock/mock_data.dart — MockData.defaultUser
What is hardcoded: Customer id u_demo, phone +919876543210, empty name
What real backend data it will eventually require: Customer record created at OTP verify
```

```text
Location: mock_data.dart — MockData.locations
What is hardcoded: 7 Ahmedabad/Surat places with labels, landmarks, some lat/lng
What real backend data it will eventually require: Customer saved addresses + geocoding/places search + current GPS
```

```text
Location: mock_data.dart — vehicles + legacyVehicles
What is hardcoded: Bike ₹79, Scooty ₹89, Three Wheeler ₹149, Truck ₹699; unused Car ₹249, Pickup ₹399; capacities; ETAs
What real backend data it will eventually require: Vehicle category master with pricing rules, capacity, availability, ETA from dispatch
```

```text
Location: lib/shared/vehicle_category/vehicle_category_catalog.dart — fallback
What is hardcoded: VC-1001 Bike available, VC-1002 Auto available, Mini Truck/Tempo/Large Tempo unavailable, Truck available
What real backend data it will eventually require: Same catalog already fetched from Admin; needs stable IDs and pricing, not name matching
```

```text
Location: mock_data.dart — demoRider
What is hardcoded: Aarav Patel, Bike GJ-01-AB-2345, rating 4.8, phone, 842 trips
What real backend data it will eventually require: Real assigned rider profile, vehicle number, live rating, contact policy
```

```text
Location: mock_data.dart — parcelCategories / parcelSizes
What is hardcoded: 8 categories, 4 sizes with cm bands
What real backend data it will eventually require: Configurable parcel catalogs (possibly admin-managed)
```

```text
Location: mock_data.dart — walletPaymentOptions
What is hardcoded: GPay, PhonePe, Paytm, Net Banking, Credit/Debit card
What real backend data it will eventually require: Payment-gateway-enabled methods, tokens, not a static list only
```

```text
Location: mock_data.dart — walletTxns
What is hardcoded: +500 added, -149 IU-1024, +50 promo credit, -249 IU-0988
What real backend data it will eventually require: Per-customer wallet ledger tied to real orders/top-ups
```

```text
Location: mock_data.dart — seedOrders()
What is hardcoded: IU-2048 inTransit ₹149; IU-1980 delivered ₹249 invoice sent to customer@example.com; IU-1766 cancelled ₹0
What real backend data it will eventually require: Customer-scoped order history from backend
```

```text
Location: session_provider.dart — walletBalance: 420
What is hardcoded: Every session starts/hydrates at ₹420
What real backend data it will eventually require: Server wallet balance
```

```text
Location: session_provider.dart — verifyOtp
What is hardcoded: Any 4-digit code succeeds; no SMS
What real backend data it will eventually require: OTP challenge, expiry, attempts, auth tokens
```

```text
Location: booking_draft_provider.dart — fareBreakdown
What is hardcoded: platform ₹10, tax 5%, vehicleCharge 15/30, distance = weight*4
What real backend data it will eventually require: Server-side fare quote using real distance/time/vehicle rules
```

```text
Location: booking_draft_provider.dart — confirmBooking / assignRider
What is hardcoded: Order id IU-{ms%100000}; always assigns demoRider after 3s
What real backend data it will eventually require: Order create API + dispatch assignment
```

```text
Location: dashboard_screen.dart
What is hardcoded: Notification badge "3"; location label MockData.locations[3] ("Other"/Vastrapur); invite ₹200; first 2 seed orders as recent
What real backend data it will eventually require: Unread notification count, live city/GPS, referral program, real recent orders
```

```text
Location: wallet_screen.dart
What is hardcoded: Method select snackbar “demo — no payment processed”; transactions from MockData
What real backend data it will eventually require: Payment intent, webhook status, ledger
```

```text
Location: searching_rider_screen.dart
What is hardcoded: Timer(3 seconds) then assignRider()
What real backend data it will eventually require: Real-time matching events
```

```text
Location: tracking_screen.dart
What is hardcoded: “Next status (Demo)” / “Mark Delivered (Demo)” advances status locally
What real backend data it will eventually require: Rider/app status events + live location
```

```text
Location: delivery_completed_screen.dart
What is hardcoded: “Invoice Generated & Sent to Email” with no send; 5 filled stars with no tap/save
What real backend data it will eventually require: Invoice document + email job; rating record
```

```text
Location: help_screen.dart
What is hardcoded: 4 FAQ titles; copy says live chat/ticketing arrive with backend
What real backend data it will eventually require: CMS FAQs and/or support tickets
```

```text
Location: profile_screen.dart — Notifications and Terms & Privacy tiles
What is hardcoded: onTap: () {}
What real backend data it will eventually require: Notification inbox; legal document URLs/content
```

```text
Location: AppConfig.apiBaseUrl
What is hardcoded: unused environment API hosts
What real backend data it will eventually require: Real authenticated customer APIs
```

---

## 6. Customer Order Flow

**Actual supported path (only these steps exist):**

```text
Splash → restore local session (if any)
 ↓
Login (10-digit phone)
 ↓
OTP (any 4 digits)
 ↓
Profile setup if name empty
 ↓
Location permission (OS; skippable)
 ↓
Home
 ↓
Pickup information
 ↓
Destination information
 ↓
Vehicle selection (optionally pre-filtered by Two/Three Wheeler/Truck)
 ↓
Parcel information
 ↓
Fare estimate (shown on parcel + summary)
 ↓
Confirm booking  →  Order created (status: searching)
 ↓
Searching (3s demo)  →  Rider assigned (status: assigned)  [cancel allowed]
 ↓
Track Delivery  →  may force invoicing email  →  status: accepted
 ↓
Tracking demo buttons advance:
   accepted → arriving → pickup → inTransit → nearDestination → delivered
 ↓
Completion screen (invoice copy + decorative stars)
```

**Payment is not a step.** Confirm Booking does not collect a method, does not debit wallet, and does not create a payment record. COD is a parcel toggle only.

**Per-step data created/updated:**

| Step | Data created / updated |
|---|---|
| Login `startLogin` | In-memory `MockUser` (id from phone hash, name/email from local maps if any) |
| OTP `verifyOtp` | `isAuthenticated=true`; persist user JSON |
| Profile setup `setName` | Customer.name; persist; known-names map |
| Location permission | **No app data** (OS permission only) |
| Pickup | `BookingDraft.pickup` |
| Drop | `BookingDraft.drop` |
| Vehicle | `BookingDraft.vehicle` (+ `serviceFamily` from home) |
| Parcel | categoryId, sizeId, weightKg, instructions, fragile, COD |
| Fare | Recalculated on draft; not stored until confirm |
| Confirm | `MockOrder` created (`searching`); `activeOrder` set; `session.orders` upserted |
| Searching 3s | status `assigned`, rider = demoRider, etaMinutes=12 |
| Cancel (searching/assigned) | status `cancelled`; draft reset; home |
| Track + email | Customer.email may be set; status `accepted` |
| Demo advance | status + etaMinutes patched; session order updated |
| Mark delivered | status `delivered`; invoiceSent/invoiceEmail; completion UI |
| Back to Home | `BookingDraft.reset()` (active booking state cleared; order remains in session memory) |

**Not in the flow:** payment capture, promo, scheduling UI, rider live GPS, POD, rating save, wallet debit.

---

## 7. Order Statuses

All values come from `OrderStatus` in `mock_models.dart`. No failed-delivery status exists.

| Status | Meaning (from `statusLabel`) | Where used | Who can change it in this app | What customer sees |
|---|---|---|---|---|
| `searching` | Searching for rider | After confirm; Searching screen | System timer (3s) or customer cancel | “Finding your rider” |
| `assigned` | Rider assigned | After timer | Customer: Track (→accepted) or Cancel | Rider card; cancel still allowed |
| `accepted` | Rider accepted | After Track Delivery | Customer demo “Next status” | Tracking timeline step 1 |
| `arriving` | Rider arriving | Tracking demo | Customer demo button | Timeline |
| `pickup` | Parcel picked up | Tracking demo | Customer demo button | Timeline |
| `inTransit` | In transit | Seed order IU-2048; tracking | Customer demo button | Timeline; dashboard Track |
| `nearDestination` | Near destination | Tracking demo | Customer demo “Mark Delivered” | Timeline |
| `delivered` | Delivered | Seed IU-1980; completion | Demo markDelivered | Completed screen; Orders filter Completed |
| `cancelled` | Cancelled | Seed IU-1766; cancelBooking | Customer, only if `canCancel` | Orders filter Cancelled; fare 0 on seed |

**Cancellation:** `canCancel` is true only for `searching` or `assigned`. After `accepted`, cancel UI is hidden. No cancel-reason field. No refund status.

**Pending / searching:** `searching`.

**Rider acceptance:** `assigned` (shown as assigned) then `accepted` (triggered by customer tapping Track Delivery, not by a rider app event in this codebase).

**Completed:** `delivered` only.

**Failed delivery:** **not present**.

**Orders list groups (not statuses):** All, Active (not delivered/cancelled), Completed (`delivered`), Cancelled.

**Timeline on tracking omits** `searching` and `assigned` as their own rows (maps them onto `accepted`).

---

## 8. Payment Data

**Order payment:** none. `Confirm Booking` stores `fare` as a number only.

**COD:** collected on `BookingDraft.cod`, **not written to `MockOrder`**, does not change fare, no collection workflow.

**Wallet**
- Balance: `SessionState.walletBalance`, default **420**, re-hardcoded on hydrate, **not persisted**.
- `addWallet(amount)` exists, **never called** by Wallet UI.
- Top-up methods: GPay / PhonePe / Paytm / NetBanking / Credit / Debit — select-only snackbar, no amount field, no charge.
- Ledger: 4 hardcoded `MockWalletTxn` rows; not updated when booking.

**Invoice**
- Not a document model.
- Flags: `invoiceSent`, `invoiceEmail`.
- Copy: “Invoice Generated & Sent to Email”.
- Email required to continue tracking if profile has no email.
- Seed delivered order uses `customer@example.com`.

**Refunds:** no fields, no UI.

**Promo codes:** no model. Wallet seed title “Promotional credit” is dummy text only. Invite banner ₹200 is copy only.

**Financial fields that exist**

| Field | Entered by customer | Calculated by app | From backend | From payment provider |
|---|---|---|---|---|
| Vehicle baseFare | No | No (hardcoded / synthesized) | Admin catalog does **not** send fare | No |
| Fare lines | No | Yes (weight/fragile/fees/tax) | No | No |
| Order.fare | No | Yes at confirm | No | No |
| Wallet balance | No | Would be via unused `addWallet` | No | No |
| Wallet txn amounts | No | No (hardcoded) | No | No |
| Payment method selection | Yes (UI only) | No | No | **Not generated — no provider** |
| Transaction ID | — | — | — | **Does not exist** |
| Invoice email | Yes | No | No | No |
| COD flag | Yes | No | No | No (unused after toggle) |

**Missing vs typical production:** payment_method on order, payment_status, provider_txn_id, wallet debit on book, refund, GST breakdown stored, fare snapshot lines on order.

---

## 9. Real-Time Requirements

Inferred from **existing screens**, not from a live stack. Tracking today is a local button, not a socket.

```text
Feature: Rider matching after confirm
Data: Order status searching → assigned; rider object
Who produces it: Today: 3-second client timer. Production: dispatch / rider accept
Who consumes it: SearchingRiderScreen, session orders
How frequently it may change: Once per booking (or retries if no rider — retries not in app)
Real-time required?: Yes (customer is on a waiting screen)
```

```text
Feature: Order status / live tracking
Data: OrderStatus, etaMinutes, pickup/drop
Who produces it: Today: customer demo button. Production: rider app / system
Who consumes it: TrackingScreen, dashboard recent, orders list
How frequently it may change: Several times per trip
Real-time required?: Yes for the tracking screen as designed
```

```text
Feature: Rider location
Data: No lat/lng field for rider. Tracking uses a static illustration (“Map preview” on pickup is also static)
Who produces it: Not implemented
Who consumes it: Tracking UI implies it
How frequently it may change: Seconds, if built
Real-time required?: Implied by “Live Tracking” copy; not implemented
```

```text
Feature: Call / message rider
Data: Rider.phone exists; buttons onPressed: () {}
Who produces it: Would be rider/customer comms
Who consumes it: RiderAssignedScreen, TrackingScreen
How frequently it may change: Per message if chat exists (it does not)
Real-time required?: Chat would; call would not need a data stream
```

```text
Feature: Wallet / payment status
Data: Method selected locally; no payment status field
Who produces it: Would be payment provider + backend
Who consumes it: WalletScreen
How frequently it may change: Per top-up attempt
Real-time required?: Useful for pending top-up; not in current code
```

```text
Feature: Notifications
Data: Hardcoded badge "3"; no payload
Who produces it: Would be backend events
Who consumes it: Dashboard icon, Profile tile (empty)
How frequently it may change: Per event
Real-time required?: Yes if inbox is built; currently none
```

```text
Feature: Vehicle category availability
Data: VehicleCategory list
Who produces it: Admin API (polled once via FutureProvider)
Who consumes it: VehicleSelectionScreen
How frequently it may change: When admin toggles availability
Real-time required?: No; refresh-on-open is enough for current UI
```

```text
Feature: Invoice email send
Data: invoiceSent / invoiceEmail
Who produces it: Local flag at deliver
Who consumes it: Completed / details
How frequently it may change: Once
Real-time required?: No (async job is enough)
```

---

## 10. Notification Requirements

There is **no Notification model, screen, service, or read/unread store**.

What exists:

```text
Notification type: Unspecified (badge only)
Trigger/event: None (badge hardcoded to 3)
Recipient: Logged-in customer UI
Message data: None
Read/unread requirement: Badge implies unread count; not implemented
Timestamp requirement: Not present
```

```text
Notification type: Profile menu “Notifications”
Trigger/event: Tap does nothing
Recipient: Customer
Message data: None
Read/unread requirement: Unknown
Timestamp requirement: Unknown
```

```text
Notification type: Invoice email (copy only)
Trigger/event: markDelivered
Recipient: Customer email string
Message data: Implied invoice; no template
Read/unread requirement: N/A (email, not in-app)
Timestamp requirement: Not stored
```

```text
Notification type: OTP SMS
Trigger/event: Login continue / Resend
Recipient: Phone
Message data: Demo snackbar “any 4 digits”; no SMS
Read/unread requirement: N/A
Timestamp requirement: 30s resend timer only
```

Order/rider events that **would** typically notify (searching done, arriving, delivered) have **no notification records** in code.

---

## 11. File / Image Storage Requirements

Customer app uses **bundled assets**, not uploads. `image_picker` / `file_picker` are in `pubspec.yaml` but **not imported** in customer Dart.

```text
File type: Profile photo
Purpose: Avatar
Where selected/uploaded: Not present. CircleAvatar shows name initial
Where displayed: ProfileScreen
Permanent or temporary: N/A — no file
```

```text
File type: Rider photo
Purpose: Assigned rider visual
Where selected/uploaded: Not by customer. MockRider.imagePath + AssetPaths.rider
Where displayed: Assigned, tracking, RiderCard (avatarUrl unused)
Permanent or temporary: Asset; production would be rider profile URL
```

```text
File type: Vehicle / parcel / invite illustrations
Purpose: UI
Where selected/uploaded: App assets (AssetPaths)
Where displayed: Dashboard, vehicle, parcel, splash, etc.
Permanent or temporary: App bundle
```

```text
File type: Parcel photo
Purpose: —
Where selected/uploaded: Not present
Where displayed: Category uses generic parcel art
Permanent or temporary: N/A
```

```text
File type: Proof of delivery
Purpose: —
Where selected/uploaded: Not present
Where displayed: Not present
Permanent or temporary: N/A
```

```text
File type: Invoice PDF
Purpose: “Invoice sent to email” copy
Where selected/uploaded: Not generated
Where displayed: Text only
Permanent or temporary: N/A
```

```text
File type: Documents (ID, etc.)
Purpose: —
Where selected/uploaded: Not in customer app (rider app has documents; out of scope)
Where displayed: N/A
Permanent or temporary: N/A
```

---

## 12. Entity Relationships

Based only on actual customer usage:

```text
Customer (MockUser)
   │
   ├── local Session (device)
   │
   ├── Saved Addresses (MockLocation, isSaved)
   │
   ├── Wallet balance (on SessionState, not a child object)
   │      └── Wallet transactions (hardcoded, not actually related by customerId)
   │
   └── Orders (MockOrder)   [in memory; not keyed by customerId]
          │
          ├── Pickup Address snapshot (MockLocation)
          ├── Drop Address snapshot (MockLocation)
          ├── Vehicle snapshot (MockVehicle)
          │      └── optionally filtered by VehicleCategory catalog
          ├── Rider snapshot (MockRider, after assign)
          ├── Status (OrderStatus)
          ├── Fare total (double; breakdown not stored)
          └── Invoice flags (invoiceSent, invoiceEmail)

BookingDraft (temporary, not a DB row)
   ├── points at pickup/drop/vehicle
   ├── parcel category/size/weight/instructions/fragile/COD
   └── becomes Order on confirm (lossy: size, fragile, COD dropped)
```

No Payment, StatusHistory, POD, Promo, Notification, or Review nodes exist in code.

---

## 13. Duplicate / Inconsistent Data

1. **Two vehicle catalogs:** `MockData.vehicles` (+ legacy car/pickup) vs `VehicleCategoryCatalog` (Bike, Auto, Mini Truck, Tempo, Large Tempo, Truck). Joined by **name string**, not ID.

2. **Vehicle naming clash:** Customer shows “Three Wheeler” (`v_auto`) but maps category name to `"Auto"`. Admin “Mini Truck” vs enum `pickup` vs legacy name “Pickup”. “Scooty” has no admin category; may vanish if catalog filter is strict.

3. **`VehicleType` vs `ServiceFamily` vs admin names** — three overlapping taxonomies.

4. **Fare stored twice conceptually:** `MockVehicle.baseFare` vs `FareBreakdown` vs `MockOrder.fare` (total only). Breakdown is not on the order.

5. **`distanceCharge` is not distance** — it is `weightKg * 4`.

6. **Status labels duplicated:** `MockOrder.statusLabel` and `TrackingScreen._labelFor` are the same switch.

7. **Address label duplicated:** `label` string and `addressLabel` enum.

8. **Icon name vs AddressLabel.iconName** both encode the same idea.

9. **Email stored in three places:** `MockUser.email`, `_knownEmails[phone]`, `MockOrder.invoiceEmail`.

10. **Orders nested full `MockLocation` + `MockVehicle` + `MockRider`** — duplicated snapshots vs catalogs; fine for orders, but seed data reuses same location/vehicle instances.

11. **Wallet txn titles** reference `IU-1024` / `IU-0988` which are **not** in `seedOrders()`.

12. **COD / fragile / size** collected then dropped at `confirmBooking()`.

13. **`scheduledAt`** on draft and order; **no screen calls `setScheduledAt`**.

14. **`instructions`** stored on order, **not shown** on Order Details.

15. **Duplicate GlassTextField / VehicleCard / theme** under `core/` and `shared/` (UI duplication, not data, but two styling sources).

16. **BookingCard / ParcelCard** exist but screens inline their own lists.

17. **User id vs phone:** id is hash of phone; known-names keyed by phone — two identifiers for one person.

18. **Order id format** `IU-{ms % 100000}` can collide and is not unique per customer.

19. **Saved addresses not scoped by user** — one device-level list; login as another number still sees same addresses.

20. **Hydrate restores user but always reloads `MockData.seedOrders()`** — new bookings disappear after kill/reopen.

21. **Cancel allowed in TrackingScreen code** but tracking is entered only after `accepted`, when `canCancel` is false — dead cancel branch on tracking.

22. **Invite ₹200** vs wallet seed “Promotional credit ₹50” — two unrelated dummy promo amounts.

23. **Capacity** is display text (`Up to 20 kg`) while weight is numeric; no validation that weight fits vehicle except copy “Parcel size not more than 36 CM” for two-wheelers (size, not weight).

---

## 14. Scalability Concerns

These are about **how the current app is structured**, if pointed at large production datasets without redesign.

1. **Orders:** `SessionState.orders` is a **full in-memory list**. Orders screen filters **on the client**. Dashboard uses `orders.take(2)` after loading all. No pagination, no cursor, no date partition.

2. **Hydrate replaces history** with 3 seed orders every launch — cannot scale and is incorrect even for one user.

3. **Address book:** entire list loaded from one JSON string in SharedPreferences; pickup/drop concatenate saved + all `MockData.locations` and **filter by substring on device**. No places API pagination.

4. **Wallet:** entire txn list rendered with `...MockData.walletTxns.map` — no paging.

5. **Vehicle catalog:** full list fetched and cached in a **process-wide static**. Fine for tens of categories; not a millions problem. Name-matching loop is O(n×m) and brittle.

6. **Nested order objects:** each order embeds full pickup, drop, vehicle (including imagePath), rider. If an API mirrored this, history payloads would be large.

7. **No customerId on orders** — cannot shard/query “orders for this user” from the model.

8. **Notification badge** cannot work at scale without a count API; loading full notification history is not even designed, but a future inbox would need paging.

9. **Fare calculated only on device** — cannot be trusted or audited at millions of orders; also diverges if two clients have different hardcoded fees.

10. **Order IDs** from `milliseconds % 100000` will collide well before millions of orders.

11. **Saved addresses / session in SharedPreferences** — unbounded JSON; no encryption (secure storage unused).

12. **Duplicate catalogs** (mock vehicles + admin categories) will drift as categories grow.

13. **Recent deliveries** always `session.orders[i]` index 0..1, not “most recent by date” query.

14. **Help / FAQ** if later loaded as a big list would be the same “load all” pattern (currently 4 static rows).

---

## 15. Security-Sensitive Data

**In the Customer App (must be protected in production):**

- Phone number  
- Customer name  
- Invoicing email  
- Saved addresses, landmarks, lat/lng  
- Auth session (`authenticated`, user id) stored in **plain SharedPreferences** (`iu_auth_v1`)  
- Rider phone (hardcoded; Call not implemented)  
- Vehicle registration string inside `vehicleLabel`  
- Wallet balance / txn amounts (financial)  
- Order history (PII + locations)

**Auth/payment:** no access tokens, no PAN/card numbers, no UPI VPA stored. OTP is dummy. Payment methods are labels only.

**Declared unused:** `flutter_secure_storage` prefix `iu_`; Hive box name only. Sensitive session currently **not** in secure storage.

**Hardcoded secrets:** none found in customer Dart (no API keys, no Firebase options file). `AppConfig` and VehicleCategoryCatalog contain **public URLs only**.

**Outside the customer app but in this workspace:** `Project_Documentation/000_info.txt` contains credentials. Do not commit or copy those values; rotate if this file was shared.

**PII in dummy data:** demo phones, `customer@example.com`, Ahmedabad addresses — treat as sample, not production users.

---

## 16. Missing Backend Requirements

Needed to support **what the Customer App already screens for**, without inventing new product features:

- Customer create/login by phone + real OTP + session tokens  
- Customer profile read/update (name, email; phone immutable)  
- Saved addresses CRUD **per customer** (label, address, city, landmark, geo)  
- Places/GPS for pickup/drop (UI search is local substring today)  
- Vehicle catalog with **pricing**, ETA, capacity, images, stable IDs aligned to booking  
- Parcel category + size catalogs  
- Fare **quote** API (distance, vehicle, weight, fragile, fees, tax) persisted as snapshot  
- Create order from draft; persist fields the UI collects (including size, fragile, COD, instructions)  
- Dispatch / assign rider; push status to customer  
- Cancel with rules matching `canCancel`  
- Order history APIs with filters Active/Completed/Cancelled + pagination  
- Order detail  
- Wallet balance + ledger + top-up intent/confirm (UI already shows methods)  
- Invoice generation + email using profile/order email  
- Optional: notification inbox + unread count (UI already has badge/tile)  
- Optional: referral/invite (banner exists, no API)  
- Optional: delivery rating (stars shown, not saved)  
- Help content or ticket API (screen is placeholder)  
- Legal documents for Terms & Privacy tile  

**Not required by current customer screens:** POD images, parcel photos, chat, live map tiles, promo-code entry, refund UI, failed-delivery states, scheduled-pickup picker (field exists, no UI).

---

## 17. Unknowns / Questions

## Questions We Need To Decide Later

These cannot be determined from the Customer App code:

1. **Source of truth for vehicles:** Admin `VehicleCategory` vs customer `MockVehicle` (pricing lives only on mock vehicles).  
2. **Is Scooty a real sellable type or only a mock extra?** Admin fallback has no Scooty.  
3. **Are Car / Pickup / Tempo / Large Tempo customer-bookable?** Legacy/admin lists disagree with home’s 3 families.  
4. **COD:** collect cash at pickup or drop? Does it change fare? Why is it not on the order?  
5. **Who pays when not COD?** Wallet, UPI at confirm, post-paid? Confirm has no payment step.  
6. **Tax 5% + platform ₹10:** real GST rules, SAC codes, invoice legal fields?  
7. **`distanceCharge` from weight:** is production distance-based? Maps/routing provider?  
8. **Fragile ₹30:** official surcharge or demo only?  
9. **Two-wheeler “36 CM” limit:** enforce vs size IDs (Small is 30 cm, Medium 60 cm)?  
10. **Scheduled booking:** keep `scheduledAt` or remove? No UI.  
11. **OTP length/provider/expiry/attempt limits** (UI is 4 digits dummy).  
12. **Can phone number ever be changed?** Edit Profile forbids it.  
13. **Email:** optional in profile vs mandatory before tracking — which is product law?  
14. **Cancel after assigned vs after accepted:** who is charged?  
15. **No-rider-found / failed delivery / return-to-sender** — no statuses.  
16. **Live tracking:** GPS interval, privacy, who publishes location?  
17. **Call rider:** in-app mask vs raw number (`MockRider.phone` exists).  
18. **Chat:** implied by Message button; no model.  
19. **Notifications:** types, channels (push vs in-app), retention.  
20. **Rating:** 1–5, optional comment, rider vs order? Stars are decorative.  
21. **Invoice:** PDF storage, GSTIN, legal entity, send vs download.  
22. **Wallet:** KYC, min/max top-up, whether deliveries debit wallet.  
23. **Promo vs referral ₹200 vs “Promotional credit ₹50”.**  
24. **Address uniqueness:** multiple Homes? SharedAddresses not per-user today.  
25. **Pickup contact / receiver phone** — not collected; needed for logistics?  
26. **Multi-stop / round trip** — not in app.  
27. **City launch / serviceability** — dummy cities mixed (Ahmedabad + Surat).  
28. **Order ID format** beyond `IU-…`.  
29. **Firebase vs PostgreSQL vs both** — customer code does not choose (Firebase placeholder only).  
30. **Whether booking draft should persist across app kill.** Currently no.

---

## 18. Recommended Database-Relevant Entities

Recommendation only. **Do not create these tables/collections in this step.**

**Keep as first-class persisted entities (clearly required by current screens):**

| Recommended entity | Why |
|---|---|
| **Customer** | Auth + profile + invoice email |
| **CustomerSession / AuthChallenge** | OTP + tokens (replace SharedPreferences auth blob) |
| **CustomerAddress** | Saved address book |
| **VehicleCategory** | Already remote; extend with fare/capacity/ETA/media |
| **ParcelCategory** | Package grid |
| **ParcelSize** | Size chips (persist on order, unlike today) |
| **Order** | Booking lifecycle |
| **OrderRoute / OrderStops** (or columns pickup_* / drop_*) | Pickup & drop snapshots |
| **OrderFareSnapshot** | Persist breakdown shown at confirm |
| **Rider** (customer-visible subset) | Assignment card |
| **Wallet** | Balance |
| **WalletTransaction** | Ledger UI |
| **Payment** (for wallet top-up at minimum) | Methods UI already exists |
| **Invoice** | Flags + email are not enough for “invoice sent” |

**Persist on Order (UI collects them but they are lost today):** `parcel_size_id`, `fragile`, `cod`, `instructions`, `service_family` (optional), `vehicle_category_id` (not only nested mock vehicle).

**Lookup / enum, not necessarily tables:** `OrderStatus`, `AddressLabel`, `WalletPaymentMethodKind`.

**Defer until product confirms (UI placeholder only):** Notification, Referral, SupportTicket, DeliveryRating, ProofOfDelivery, ChatMessage, PromoCode, ScheduledJob.

**Do not model as production entities:** `BookingDraft` (session/cache), `SessionState.isHydrated`, `FareBreakdown` as a live calculator without snapshot, `MockData` catalogs once replaced by masters.

**Suggested relationship (production-oriented, still grounded in the app):**

```text
Customer
   ├── Addresses
   ├── Wallet
   │      ├── WalletTransactions
   │      └── Payments (top-up)
   └── Orders
          ├── VehicleCategory (reference) + vehicle snapshot
          ├── ParcelCategory / ParcelSize
          ├── Rider (reference) + rider snapshot
          ├── FareSnapshot
          ├── Status (and later StatusHistory if tracking stays event-driven)
          └── Invoice
```

---

**End of analysis.** No code, files, databases, or dummy data were changed. This report is ready as input for the production database architecture step.
