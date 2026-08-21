# Design System Widgets

Reusable UI foundation for **IDHAR UDHAR**. Tokens and components mirror the reference splash, onboarding, auth, OTP, and location screens.

Import barrels:

```dart
import 'package:idhar_udhar/core/theme/theme.dart';
import 'package:idhar_udhar/core/widgets/widgets.dart';
import 'package:idhar_udhar/core/animations/animations.dart';
```

---

## Theme (`lib/core/theme/`)

| File | Purpose |
|------|---------|
| `app_colors.dart` | Orange `#FF6A00`, navy `#183B73`, warm white, soft peach, glass fills, semantic colors |
| `app_gradients.dart` | Primary CTA, navy→orange CTA, sunset / cream / peach backgrounds, orange ambient |
| `app_text_styles.dart` | Heading XL/L/M, body, caption, button, OTP, wordmark, mixed headline helper |
| `app_spacing.dart` | Scale `2…64` plus screen / card / button / input tokens |
| `app_radius.dart` | `sm…xxl`, pill, OTP radii |
| `app_shadows.dart` | Glass, floating, soft, orange glow, soft white glow, input / OTP focus |
| `glass_effect.dart` | Backdrop blur + opacity + white border + shadow surface |
| `app_theme.dart` | Material 3 `ThemeData` mapped to brand tokens |

---

## Widgets (`lib/core/widgets/`)

| Widget | Description |
|--------|-------------|
| **GlassCard** | Large frosted panel (auth cards). Configurable blur intensity and radius. |
| **PrimaryButton** | Capsule orange-gradient CTA with ambient glow and trailing arrow chip. |
| **SecondaryButton** | Navy text / ghost action with optional leading or trailing chevron. |
| **AnimatedPrimaryButton** | Primary CTA + press scale (0.98) and light haptic. |
| **GlassTextField** | Rounded glass field, orange leading icon, focus glow, password visibility. |
| **OTPBox** / **OTPInputRow** | Digit cell with orange glow; 6-box row with auto-advance. |
| **PageIndicator** | Active elongated orange dot; inactive soft grey. |
| **TopLogo** | Official logo PNG (`AssetPaths.logo`). Default `showWordmark: false` (PNG already includes wordmark). Optional painted wordmark / tagline + Hero; painted fallback mark if asset missing. |
| **ScreenBackground** | Full-bleed image (falls back to sunset gradient) + light scrim. |
| **GradientBackground** | Cream / sunset / peach gradient scaffolds. |
| **LoadingIndicator** | Splash-style capsule progress bar or circular spinner. |
| **VehicleCard** | Selectable vehicle tile; orange border + scale-in check badge. |
| **FeatureCard** | Icon well + title/subtitle row with chevron (permission / how-it-works). |
| **FloatingGlassCard** | Compact floating chip for onboarding overlays. |

---

## Animations (`lib/core/animations/`)

| Widget / token | Description |
|----------------|-------------|
| **AppMotion** | Duration and curve tokens (micro → float) |
| **FadeAnimation** | Opacity entrance |
| **SlideAnimation** | Slide + optional fade from any edge |
| **ScaleAnimation** | Pop / pulse scale |
| **AppHero** | Typed Hero tags for logo and vehicles |
| **ButtonPressAnimation** | Press scale + haptic |
| **FloatingAnimation** | Looping vertical float |
| **ParallaxAnimation** / **ParallaxScrollLayer** | Offset-driven / scroll-linked parallax |

All motion respects `MediaQuery.disableAnimations`.

---

## Usage notes

- Prefer spacing / radius / color tokens — no magic numbers in feature UI.
- Prefer `GlassEffect` / `GlassCard` over one-off blur containers.
- Primary actions use `AnimatedPrimaryButton` or `PrimaryButton`.
- Do not duplicate these widgets under `shared/` — extend here or compose.

This layer contains **no** auth, Firebase, API, or booking logic.
