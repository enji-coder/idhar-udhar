# Shared UI Kit

Reusable design-system façade for **IDHAR UDHAR**.

## Import

```dart
import 'package:idhar_udhar/shared/theme/theme.dart';
import 'package:idhar_udhar/shared/widgets/widgets.dart';
```

## Architecture rule

- **Tokens & primitives** live in `lib/core/theme`, `lib/core/widgets`, `lib/core/animations`.
- **`lib/shared`** re-exports those tokens and adds kit-level composites (cards, chrome, feedback).
- Do **not** redefine brand hex / spacing values here.
- Completed auth screens continue importing `lib/core/*` and were **not** modified.

## Theme (`lib/shared/theme/`)

| File | Role |
|------|------|
| `colors.dart` | Re-exports `AppColors` |
| `gradients.dart` | Re-exports `AppGradients` |
| `text_styles.dart` | Re-exports `AppTextStyles` |
| `spacing.dart` | Re-exports `AppSpacing` |
| `radius.dart` | Re-exports `AppRadius` |
| `shadows.dart` | Re-exports `AppShadows` |
| `durations.dart` | `AppDurations` → `AppMotion` |
| `animations.dart` | `AppAnimations` helpers (fade/slide/scale/hero/page) |

## Widgets (`lib/shared/widgets/`)

| Widget | Notes |
|--------|-------|
| `GlassContainer` | **One** glass surface (blur/opacity/border/shadow/radius) |
| `GlassCard` | Auth-style panel → core `GlassCard` |
| `GradientButton` / `LoadingButton` | Primary CTA → core buttons |
| `GlassButton` | Secondary frosted pill |
| `OutlineButton` | Navy outline capsule |
| `CustomIconButton` | Glass / solid icon hit target |
| `GlassTextField` | text/password/phone/email/search/multiline → core field |
| `AnimatedCard` | Glass + fade/slide/scale entrance |
| `VehicleCard` | → core `VehicleCard` |
| `ParcelCard` | Parcel type selection |
| `BookingCard` | Booking list summary |
| `RiderCard` | Rider identity + actions |
| `CustomAppBar` | Transparent M3 app bar |
| `SectionTitle` | Heading + optional action |
| `CustomBottomSheet` | Modal sheet helper |
| `CustomDialog` | Confirm / cancel dialog |
| `CustomSnackBar` | Floating tone snackbars |
| `LoadingWidget` | → core `LoadingIndicator` |
| `ShimmerWidget` | Skeleton placeholders |
