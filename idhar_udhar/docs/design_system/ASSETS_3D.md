# IDHAR UDHAR — 3D Asset Family

Official Pixar-inspired / studio-rendered logistics illustrations.

| Field | Value |
|-------|--------|
| Root folder | `assets/images/3d/` |
| Pubspec entry | `assets/images/3d/` |
| Dart constants | `lib/core/constants/asset_paths.dart` (`AssetPaths.*`) |
| Visual family | Navy / white / orange, soft studio lighting, consistent proportions |
| Rule | Use existing files via `AssetPaths`. Do not generate replacements unless instructed. |

**Brand colors (code tokens):** orange `#FF6A00`, navy `#183B73`.

---

## Inventory (files present on disk)

| AssetPaths | Filename | Purpose | Category | Branding in artwork | Intended use |
|------------|----------|---------|----------|---------------------|--------------|
| `truck` | `idhar_udhar_delivery_truck.png` | Box cargo delivery truck | Vehicle | Yes — full logo + wordmark on cargo side | Splash hero, vehicle selection, booking |
| `bike` | `idhar_udhar_delivery_bike.png` | Delivery scooter with rear box | Vehicle | Brand livery (navy/white/orange); cargo panel for mark | Vehicle selection, small-parcel booking |
| `auto` | `idhar_udhar_auto_rickshaw.png` | Three-wheeler / auto rickshaw | Vehicle | Brand colors; white cargo panel for mark | Vehicle selection |
| `car` | `idhar_udhar_car.png` | Compact hatchback | Vehicle | Yes — full logo + wordmark on door | Vehicle selection |
| `pickupTruck` | `idhar_udhar_pickup_truck.png` | Small flatbed / pickup | Vehicle | Brand colors + orange swoosh accents | Vehicle selection, medium loads |
| `parcel` | `idhar_udhar_parcel.png` | Single cardboard parcel | Parcel | Yes — full logo + wordmark | Package details, empty states |
| `parcelStack` | `idhar_udhar_parcel_stack.png` | Stack of branded parcels | Parcel | Yes — logos on boxes | Multi-parcel / capacity cues |
| `rider` | `idhar_udhar_rider.png` | Standing delivery rider | Character | Yes — small mark on jacket | Rider assigned, profile chrome |
| `locationPin` | `idhar_udhar_location_pin.png` | Map location pin | UX / map | Brand colors only (no wordmark) | Pickup/drop, maps, location permission |
| `invite` | `idhar_udhar_invite.png` | Invite / refer composition | Marketing | Brand colors; share network motif (no baked wordmark) | Invite friends, referrals |
| `searchingRider` | `idhar_udhar_searching_rider.png` | Rider + scooter + pin network | Status | Yes — logo on scooter box | Finding rider / searching state |
| `deliveryProgress` | `idhar_udhar_delivery_progress.png` | Rider in transit + route pin | Status | Yes — logo on delivery box | Live tracking / in-progress |
| `movingItems` | `idhar_udhar_moving_items.png` | Furniture, luggage, boxes | Parcel / service | Brand colors on items (no wordmark) | Home shifting / large-move category |

---

## Aliases (legacy names → 3D)

These keep older call sites working without duplicating files:

| Alias | Resolves to |
|-------|-------------|
| `vehicleBike` | `bike` |
| `vehiclePickup` | `pickupTruck` |
| `vehicleMiniTruck` | `truck` |
| `parcelSmall` | `parcel` |
| `parcelLarge` | `parcelStack` |
| `parcelHomeShifting` | `movingItems` |

---

## Related non-3D illustrations (also shipped)

| AssetPaths | Path | Notes |
|------------|------|-------|
| `splashDeliveryTruck` | `assets/illustrations/splash/splash_delivery_truck.png` | Splash-specific truck |
| `loginDeliveryTruck` | `assets/illustrations/login/login_delivery_truck.png` | Login hero truck |
| `logo` | `assets/logos/idhar_udhar_logo.png` | **Only** approved 2D logo (mark + wordmark) |

---

## Usage

```dart
SafeAssetImage(
  path: AssetPaths.truck,
  fit: BoxFit.contain,
)
```

Do **not** hardcode `assets/images/3d/...` strings in feature widgets.
Do **not** overlay flat logos onto surfaces that already include baked branding.
