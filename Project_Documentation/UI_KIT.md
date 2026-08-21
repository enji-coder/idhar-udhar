# IDHAR UDHAR — UI Kit

> Catalog of **reusable UI that exists in code today**.  
> Source of truth: `idhar_udhar/lib/core/*` and `idhar_udhar/lib/shared/*`.  
> Companion in-app docs: `idhar_udhar/docs/design_system/WIDGETS.md`, `SHARED_UI_KIT.md`.

**Last reviewed:** 2026-08-06

---

## 1. Architecture rule

| Layer | Path | Role |
|-------|------|------|
| Tokens & primitives | `lib/core/theme`, `lib/core/widgets`, `lib/core/animations` | Brand design system |
| Shared kit | `lib/shared/theme`, `lib/shared/widgets` | Façades + higher-level composites |
| Feature UI | `lib/features/<feature>/presentation` | Screens composing the above |

- Do **not** hardcode brand hex, spacing, or radii in feature screens.
- Completed first-run screens import **`package:idhar_udhar/core/...`**.
- Prefer shared kit imports for **new** screens once approved:

```dart
import 'package:idhar_udhar/shared/theme/theme.dart';
import 'package:idhar_udhar/shared/widgets/widgets.dart';
// or core barrels when composing primitives directly:
import 'package:idhar_udhar/core/theme/theme.dart';
import 'package:idhar_udhar/core/widgets/widgets.dart';
import 'package:idhar_udhar/core/animations/animations.dart';
```

---

## 2. Brand tokens (implemented)

### Colors (`AppColors`)

| Token | Hex / value | Use |
|-------|-------------|-----|
| `orange` | `#FF6A00` | Primary CTA / accents (`AppColors.orange`) |
| `orangePressed` / `orangeSoft` / `orangeDeep` / `orangeGlow` | variants | Pressed / soft / deep / glow |
| `navy` | `#183B73` | Headings / secondary (`AppColors.navy`) |
| `navyDeep` / `navyMuted` | `#183B73` / `#294A8A` | Text hierarchy (matches `AppColors`) |
| Surfaces | warm white, cream, soft peach, peach | Backgrounds |
| Glass fills | translucent whites | Frosted panels |
| Semantic | success, warning, danger, info | Status only |

### Typography (`AppTextStyles`)

- Family: **Poppins** via `google_fonts` (pinned `6.1.0` in `pubspec.yaml`).
- Styles present: `headingXL` / `L` / `M` / `S`, body variants, caption, label, button, OTP, wordmark orange/navy, `mixedHeadline(...)`.

### Spacing / radius / shadows / gradients

- `AppSpacing` — scale and named layout tokens (screen margin, button height, OTP size, logo heights, …).
- `AppRadius` — `sm`…`xxl`, pill, OTP.
- `AppShadows` — glass, floating, soft, orange glow, white glow, input/OTP focus.
- `AppGradients` — primary CTA, navy→orange CTA, sunset / cream / peach backgrounds, ambient radial.

### Glass (`GlassEffect`)

- `BackdropFilter` blur + fill + border + shadow.
- Intensity presets: soft / medium / heavy.
- Falls back when reduced motion / low-end path applies (as implemented in code).

### Material theme (`AppTheme.light`)

- Material 3 `ThemeData` mapped to brand colors, typography, inputs, buttons, checkbox, snackbar, progress.

### Motion (`AppMotion` + primitives)

| Primitive | File |
|-----------|------|
| Duration/curve tokens | `app_motion.dart` |
| `FadeAnimation` | `fade_animation.dart` |
| `SlideAnimation` | `slide_animation.dart` |
| `ScaleAnimation` | `scale_animation.dart` |
| `AppHero` | `hero_animation.dart` |
| `ButtonPressAnimation` | `button_press_animation.dart` |
| `FloatingAnimation` | `floating_animation.dart` |
| `ParallaxAnimation` / `ParallaxScrollLayer` | `parallax_animation.dart` |

Shared façades: `AppDurations`, `AppAnimations` under `lib/shared/theme/`.

---

## 3. Core widgets (`lib/core/widgets/`)

| Widget | Purpose |
|--------|---------|
| `GlassCard` | Large frosted auth-style panel |
| `PrimaryButton` | Capsule orange-gradient CTA + glow + arrow chip |
| `SecondaryButton` | Navy text/ghost action ± chevrons |
| `AnimatedPrimaryButton` | Primary + press scale + haptic |
| `GlassTextField` | Glass input (icon, focus, password, error) |
| `OTPBox` / `OTPInputRow` | Single cell / 6-digit auto-advance row |
| `PageIndicator` | Onboarding dots (active elongated orange) |
| `TopLogo` | Logo asset + wordmark ± tagline / Hero; painted fallback |
| `ScreenBackground` | Image + scrim; gradient fallback if asset missing |
| `GradientBackground` | Cream / sunset / peach scaffolds |
| `LoadingIndicator` | Capsule progress or circular spinner |
| `VehicleCard` | Selectable vehicle tile |
| `FeatureCard` | Icon + title/subtitle row |
| `FloatingGlassCard` | Compact floating chip |

Barrel: `lib/core/widgets/widgets.dart`.

---

## 4. Shared kit widgets (`lib/shared/widgets/`)

| Widget | Notes |
|--------|--------|
| `GlassContainer` | Configurable glass surface (blur/opacity/border/shadow/radius) |
| `GlassCard` | Delegates to core `GlassCard` |
| `GradientButton` / `LoadingButton` | Primary CTA wrapping core buttons |
| `GlassButton` | Secondary frosted pill |
| `OutlineButton` | Navy outline capsule |
| `CustomIconButton` | Glass / solid icon hit target |
| `GlassTextField` | Typed variants over core field |
| `AnimatedCard` | Glass + entrance motion |
| `VehicleCard` | → core `VehicleCard` |
| `ParcelCard` | Parcel-type selection card |
| `BookingCard` | Booking list summary card |
| `RiderCard` | Rider identity + actions card |
| `CustomAppBar` | Transparent M3 app bar |
| `SectionTitle` | Heading + optional action |
| `CustomBottomSheet` | Modal sheet helper |
| `CustomDialog` | Confirm / cancel dialog |
| `CustomSnackBar` | Floating tone snackbars |
| `LoadingWidget` | → core `LoadingIndicator` |
| `ShimmerWidget` | Skeleton placeholders |

Barrel: `lib/shared/widgets/widgets.dart`.

Empty reserved folders (no widgets yet): `shared/bottomsheet`, `buttons`, `cards`, `common`, `dialogs`, `loaders`, `navigation`, `textfields`.

---

## 5. Screens that already consume the kit

| Screen | Primary building blocks used |
|--------|------------------------------|
| Splash | `GradientBackground`, `TopLogo`, `LoadingIndicator`, float/fade/scale |
| Onboarding | `GradientBackground`, `FloatingGlassCard`, `PageIndicator`, `AnimatedPrimaryButton`, `SecondaryButton`, painted illustrations |
| Login | `ScreenBackground`, `GlassCard`, `GlassTextField`, `AnimatedPrimaryButton`, `TopLogo` |
| OTP | `ScreenBackground`, `GlassCard`, `OTPInputRow`, `AnimatedPrimaryButton`, `SecondaryButton` |
| Location permission | `GradientBackground.peach`, `GlassCard`, `FeatureCard`, `AnimatedPrimaryButton`, `SecondaryButton`, painted illustration |

---

## 6. Assets tied to the UI kit

| Path | Status |
|------|--------|
| `assets/logos/idhar_udhar_logo.png` | Present — used by `TopLogo` |
| All other `AssetPaths` entries | Declared; files pending — load via `SafeAssetImage` |
| Auth background | Login/OTP use `AssetPaths.authBackground` → sunset gradient if missing |
| Onboarding / location | Prefer WebP paths → painted `CustomPaint` fallback |
| Vehicle cards | Prefer `imagePath` → shipping icon fallback |

Registry: `lib/core/constants/asset_paths.dart`.

---

## 7. Out of scope of this UI kit (not in code)

- Firebase-driven UI states
- Map widgets
- Payment / booking flow screens
- Rider-specific screens
- Dark theme `ThemeData` (light theme only today)
