# Phase 02 — UI Foundation

## 1. Overview

This document catalogs everything delivered in the **Global UI Foundation** phase for **IDHAR UDHAR**.

**Goal:** A production-ready, reusable design system that matches the reference screens (splash, onboarding, login, registration, OTP, forgot password, location permission, vehicle selection).

**Scope of this phase**

| Included | Excluded |
|----------|----------|
| Design tokens (color, type, space, radius, shadow, gradient) | Authentication flows |
| Glassmorphism primitives | Firebase / APIs |
| Reusable core widgets | Booking / business logic |
| Reusable animation primitives | Feature screens |
| Material 3 brand `ThemeData` | Redesigns or simplifications of the references |
| Widget catalog documentation | Duplicate widgets under `shared/` |

**Source of truth:** Uploaded UI reference images + `16_Design_System.md` / `17_Animation_Guidelines.md`.

**App package:** `idhar_udhar` (`com.idharudhar.idhar_udhar`)

**Related in-app catalog:** `idhar_udhar/docs/design_system/WIDGETS.md`

---

## 2. Folder Structure

```
idhar_udhar/
├── lib/
│   ├── main.dart                          # Boots app with AppTheme.light
│   ├── config/                            # (prior phase) AppConfig, Environment
│   └── core/
│       ├── constants/
│       │   └── asset_paths.dart
│       ├── theme/
│       │   ├── theme.dart                 # Barrel export
│       │   ├── app_colors.dart
│       │   ├── app_text_styles.dart
│       │   ├── app_spacing.dart
│       │   ├── app_radius.dart
│       │   ├── app_shadows.dart
│       │   ├── app_gradients.dart
│       │   ├── glass_effect.dart
│       │   └── app_theme.dart
│       ├── widgets/
│       │   ├── widgets.dart               # Barrel export
│       │   ├── glass_card.dart
│       │   ├── primary_button.dart
│       │   ├── secondary_button.dart
│       │   ├── animated_primary_button.dart
│       │   ├── glass_text_field.dart
│       │   ├── otp_box.dart
│       │   ├── page_indicator.dart
│       │   ├── top_logo.dart
│       │   ├── screen_background.dart
│       │   ├── gradient_background.dart
│       │   ├── loading_indicator.dart
│       │   ├── vehicle_card.dart
│       │   ├── feature_card.dart
│       │   └── floating_glass_card.dart
│       └── animations/
│           ├── animations.dart            # Barrel export
│           ├── app_motion.dart
│           ├── fade_animation.dart
│           ├── slide_animation.dart
│           ├── scale_animation.dart
│           ├── hero_animation.dart
│           ├── button_press_animation.dart
│           ├── floating_animation.dart
│           └── parallax_animation.dart
├── assets/
│   └── logos/idhar_udhar_logo.png
├── docs/
│   └── design_system/WIDGETS.md
└── Project_Documentation/
    └── Phase_02_UI_Foundation.md          # This file
```

Feature folders under `lib/features/` remain empty shells from project initialization and are **not** part of this UI foundation delivery.

---

## 3. Files Created — Purpose of Every File

### 3.1 Theme layer (`lib/core/theme/`)

| File | Purpose |
|------|---------|
| `theme.dart` | Barrel: re-exports all theme modules for a single import. |
| `app_colors.dart` | Brand, surface, text, border, glass, semantic, and overlay color tokens. |
| `app_text_styles.dart` | Poppins text styles (via `google_fonts`) and mixed navy/orange headline helper. |
| `app_spacing.dart` | Numeric spacing scale and named layout tokens (screen margin, button height, etc.). |
| `app_radius.dart` | Corner radius values and ready-made `BorderRadius` constants. |
| `app_shadows.dart` | Glass, floating, soft, orange CTA glow, white glow, input/OTP focus shadows. |
| `app_gradients.dart` | CTA gradients, sunset/cream/peach backgrounds, ambient radial glows. |
| `glass_effect.dart` | Reusable frosted-glass surface (`BackdropFilter` + fill + border + shadow) with intensity presets and low-end fallback. |
| `app_theme.dart` | Material 3 `ThemeData.light` mapped to brand colors, typography, inputs, buttons, checkboxes, snackbars. |

### 3.2 Widget layer (`lib/core/widgets/`)

| File | Purpose |
|------|---------|
| `widgets.dart` | Barrel export for all core widgets. |
| `glass_card.dart` | Large auth-style glass panel wrapping `GlassEffect`. |
| `primary_button.dart` | Capsule orange-gradient CTA with glow and trailing arrow chip. |
| `secondary_button.dart` | Navy text/ghost secondary action with optional chevrons. |
| `animated_primary_button.dart` | Primary CTA composed with press-scale + haptic feedback. |
| `glass_text_field.dart` | Rounded glass input with leading icon, focus glow, password toggle, error caption. |
| `otp_box.dart` | Single OTP cell + `OTPInputRow` (6-box auto-advance row). |
| `page_indicator.dart` | Onboarding/auth dots; active = elongated orange. |
| `top_logo.dart` | Brand mark + wordmark (IDHAR orange / UDHAR navy), optional tagline, Hero support, painted fallback mark. |
| `screen_background.dart` | Full-bleed image background with scrim; gradient fallback if asset missing. |
| `gradient_background.dart` | Cream / sunset / peach gradient scaffolds. |
| `loading_indicator.dart` | Splash-style capsule progress bar or circular spinner. |
| `vehicle_card.dart` | Selectable vehicle tile with orange border, check badge, optional Hero. |
| `feature_card.dart` | Icon-well + title/subtitle row (permission / how-it-works lists). |
| `floating_glass_card.dart` | Compact floating glass chip for onboarding overlays. |

### 3.3 Animation layer (`lib/core/animations/`)

| File | Purpose |
|------|---------|
| `animations.dart` | Barrel export for motion primitives. |
| `app_motion.dart` | Duration, curve, and micro-interaction constants. |
| `fade_animation.dart` | Opacity entrance for cards and content. |
| `slide_animation.dart` | Edge slide + optional fade (auth card enter). |
| `scale_animation.dart` | Scale pop for checks, badges, micro-feedback. |
| `hero_animation.dart` | `AppHero` with typed tags for logo and vehicles. |
| `button_press_animation.dart` | Press scale to `0.98` + light haptic + spring release. |
| `floating_animation.dart` | Looping vertical float for decorative layers. |
| `parallax_animation.dart` | Offset-driven parallax + scroll-linked layer helper. |

### 3.4 Supporting files updated/used in this phase

| File | Role |
|------|------|
| `lib/core/constants/asset_paths.dart` | Central asset path constants (`logo`, folder roots). |
| `lib/main.dart` | Applies `AppTheme.light`; no feature UI. |
| `docs/design_system/WIDGETS.md` | Short in-repo widget/theme/animation catalog. |
| `assets/logos/idhar_udhar_logo.png` | Brand logo used by `TopLogo`. |

---

## 4. Theme Architecture

```
AppTheme.light (Material 3)
        │
        ├── ColorScheme  ← AppColors (orange primary, navy secondary, cream surface)
        ├── TextTheme    ← AppTextStyles (Poppins via Google Fonts)
        ├── InputDecorationTheme ← glass-like fields, orange focus
        ├── Button themes ← stadium / navy text
        └── Component themes ← checkbox, progress, snackbar
                │
Feature screens compose:
  AppColors / AppSpacing / AppRadius / AppShadows / AppGradients
  GlassEffect → GlassCard / GlassTextField / cards
  PrimaryButton / AnimatedPrimaryButton / SecondaryButton
  Fade / Slide / Scale / AppHero / Floating / Parallax
```

**Rules**

1. **Tokens first** — Never hardcode hex, spacing, or radii in feature screens.
2. **Glass via primitive** — Use `GlassEffect` / `GlassCard`; do not invent new blur containers.
3. **M3 for behavior** — Ripples, scaffolds, semantics from Material 3; visuals from brand tokens (no default purple seed).
4. **Accessibility** — Prefer navy text on glass; selection never relies on color alone (e.g. check badge on `VehicleCard`).
5. **Performance** — `GlassEffect` disables blur when `MediaQuery.disableAnimations` is true and falls back to solid cream fill.

---

## 5. Design Tokens

### 5.1 Colors (`AppColors`)

| Token group | Key values | Usage |
|-------------|------------|--------|
| Brand orange | `#FF6624`, soft `#FF8A4A`, pressed `#E55A1F`, deep `#FF4D00` | CTAs, accents, IDHAR wordmark, focus |
| Brand navy | `#2E4072`, deep `#1A2B4C`, muted `#5C6B8A` | Headings, UDHAR wordmark, secondary actions |
| Surfaces | Warm white `#FFFBFA`, cream `#FFF7F0`, soft peach `#FFE4D4` | Onboarding / soft backgrounds |
| Glass fills | White @ ~45–85% opacity variants | Frosted cards and fields |
| Text | Primary navy-deep, secondary muted, inverse white | Hierarchy on glass and CTAs |
| Semantic | Success, warning, danger, info | Status only — not decorative brand |

### 5.2 Typography (`AppTextStyles`)

| Style | Approx size / weight | Use |
|-------|----------------------|-----|
| `headingXL` | 30 / Bold | Onboarding heroes |
| `headingL` | 24 / Bold | Auth titles |
| `headingM` | 20 / SemiBold | Section titles |
| `headingS` | 16 / SemiBold | Card titles |
| `body` / `bodyMedium` / `bodyLarge` | 14–15 | Descriptions and field text |
| `caption` / `label` | 12–13 | Fine print, field labels |
| `button` / `buttonSecondary` | 15–16 / SemiBold | CTAs |
| `otp` | 22 / Bold | OTP digits |
| `wordmarkOrange` / `wordmarkNavy` | 18 / ExtraBold | Brand wordmark |
| `mixedHeadline(...)` | — | Navy + orange split titles (“Forgot **Password?**”) |

**Family:** Poppins (`google_fonts`, pinned `6.1.0` for Flutter 3.16.x compatibility).

### 5.3 Spacing (`AppSpacing`)

Scale: `2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64`

Named tokens include:

- `screenHorizontal` / `screenHorizontalCompact` — 24 / 20  
- `cardPadding` / `cardPaddingCompact` — 24 / 20  
- `buttonHeight` / `inputHeight` — 56  
- `otpBoxSize` — 48  
- `fieldGap`, `sectionGap`, icon sizes, logo heights  

**Rule:** No magic numbers in feature UI — use these tokens.

### 5.4 Radius (`AppRadius`)

| Token | Value | Use |
|-------|-------|-----|
| `sm` | 12 | Chips, small cards |
| `md` / `mdLg` | 16 / 20 | Inputs, floating chips |
| `lg` / `lgXl` | 24 / 28 | Medium panels, vehicle cards |
| `xl` / `xxl` | 32 / 40 | Auth glass cards |
| `otp` | 14 | OTP cells |
| `pill` | 999 | Primary buttons, indicators |

### 5.5 Shadows (`AppShadows`)

| Token | Intent |
|-------|--------|
| `glass` / `glassEdge` | Auth / content glass elevation |
| `floating` | Onboarding floating chips |
| `soft` | Light elevation / unselected cards |
| `orangeGlow` / `orangeGlowPressed` | Primary CTA ambient glow |
| `softWhiteGlow` | Soft highlight on glass edges |
| `inputFocus` / `otpFocus` | Orange focus glow |

### 5.6 Gradients (`AppGradients`)

| Token | Intent |
|-------|--------|
| `primaryCta` / `primaryCtaSoft` | Orange capsule buttons |
| `navyOrangeCta` | Onboarding-style Next (navy → orange) |
| `sunsetBackground` / `sunsetRadial` | Auth / cinematic backgrounds |
| `warmCream` / `peachGlow` | Soft onboarding canvases |
| `orangeAmbient` | Radial glow accents |
| `glassSheen` | Subtle glass highlight |

### 5.7 Glass intensity (`GlassIntensity`)

| Value | Blur (approx) | Fill |
|-------|---------------|------|
| `soft` | 16 | Lighter translucent white |
| `medium` | 20 | Standard auth glass |
| `heavy` | 24 | Dense floating chips |

---

## 6. Reusable Widgets

### 6.1 Surfaces & layout

| Widget | Role | Typical screens |
|--------|------|-----------------|
| `GlassEffect` | Low-level glass surface | Building block for cards/fields |
| `GlassCard` | Large frosted content panel | Login, register, OTP, forgot password, location |
| `ScreenBackground` | Photo + scrim (gradient fallback) | Auth stack |
| `GradientBackground` | Cream / sunset / peach scaffolds | Onboarding, soft flows |
| `TopLogo` | Mark + wordmark (+ optional tagline/Hero) | Splash, auth headers |
| `LoadingIndicator` | Capsule bar or circular loader | Splash, async waits |
| `PageIndicator` | Dot pager | Onboarding, multi-step auth |

### 6.2 Actions

| Widget | Role |
|--------|------|
| `PrimaryButton` | Capsule gradient CTA + arrow + glow |
| `AnimatedPrimaryButton` | Same + press animation + haptic |
| `SecondaryButton` | “Back”, “Not Now”, text links with chevrons |

### 6.3 Inputs

| Widget | Role |
|--------|------|
| `GlassTextField` | Name, mobile, email, password fields |
| `OTPBox` | Single digit cell |
| `OTPInputRow` | Complete 6-digit OTP entry with focus advance |

### 6.4 Cards & content rows

| Widget | Role |
|--------|------|
| `VehicleCard` | Bike / pickup / mini-truck selection |
| `FeatureCard` | Benefit rows (location permission, how-it-works) |
| `FloatingGlassCard` | Overlay chips on onboarding illustrations |

---

## 7. Animation System

### 7.1 Motion tokens (`AppMotion`)

| Token | Value | Use |
|-------|-------|-----|
| `micro` / `fast` | 150–180 ms | Press, micro UI |
| `normal` | 280 ms | Component transitions |
| `enter` | 400 ms | Screen / card entrance |
| `page` | 350 ms | Page changes |
| `float` | 2400 ms | Decorative float loop |
| `pressScale` | 0.98 | CTA press |
| `enterSlide` | 24 | Auth card slide distance |

Curves: `easeOut`, `easeInOut`, `easeOutCubic`, `easeOutBack` (spring), `linear`.

### 7.2 Primitives

| Primitive | Behavior |
|-----------|----------|
| `FadeAnimation` | Fade in with delay support |
| `SlideAnimation` | From bottom/top/left/right + optional fade |
| `ScaleAnimation` | Pop / optional repeating pulse |
| `AppHero` | `AppHero.logo`, `AppHero.vehicle(id:)` |
| `ButtonPressAnimation` | Scale + haptic; wraps any child |
| `FloatingAnimation` | Gentle vertical oscillation |
| `ParallaxAnimation` | Manual offset factor |
| `ParallaxScrollLayer` | ScrollController-linked parallax |

**Reduced motion:** All primitives short-circuit to static children when `MediaQuery.disableAnimations` is true.

---

## 8. Dependencies Used by This Phase

These packages were already declared in project initialization; the UI foundation **consumes** them (not newly invented APIs):

| Package | Role in UI foundation |
|---------|------------------------|
| `google_fonts` **`6.1.0`** (pinned) | Poppins typography |
| `flutter` SDK | Material 3, `BackdropFilter`, animations |
| `cupertino_icons` | Optional icon set |

**Not required to call in this phase (available for later features):**  
`flutter_riverpod`, `go_router`, `dio`, `hive*`, Firebase packages (not added), Maps, etc.

**Dev note:** `google_fonts` is pinned to `6.1.0` because newer versions conflicted with Flutter SDK **3.16.9** in this environment. Upgrade Flutter before bumping `google_fonts`.

---

## 9. How Future Screens Should Use These Components

### 9.1 Imports

```dart
import 'package:idhar_udhar/core/theme/theme.dart';
import 'package:idhar_udhar/core/widgets/widgets.dart';
import 'package:idhar_udhar/core/animations/animations.dart';
import 'package:idhar_udhar/core/constants/asset_paths.dart';
```

### 9.2 Screen recipe (auth example)

1. **Scaffold** — Prefer `ScreenBackground` (photo) or `GradientBackground.sunset`.
2. **Header** — `TopLogo(showWordmark: true)`.
3. **Title** — `Text.rich` using `AppTextStyles.mixedHeadline(...)`.
4. **Body panel** — Wrap form in `SlideAnimation` + `GlassCard`.
5. **Fields** — `GlassTextField` with `AppSpacing.fieldGap` between fields.
6. **Primary action** — `AnimatedPrimaryButton(label: '...', onPressed: ...)`.
7. **Secondary** — `SecondaryButton` for Back / Skip-style actions.
8. **Chrome** — `PageIndicator` when part of a multi-step flow.

### 9.3 Onboarding recipe

1. `GradientBackground` (warm cream / peach).
2. Headline with mixed colors.
3. Illustration layer; decorate with `FloatingGlassCard` + optional `FloatingAnimation`.
4. Bottom sheet area with `PageIndicator` + `AnimatedPrimaryButton` / `SecondaryButton`.
5. Page changes: prefer horizontal shared-axis at router level; content can use `FadeAnimation` / `SlideAnimation`.

### 9.4 Vehicle selection recipe

```text
Row/List of VehicleCard(
  title, image/imagePath, selected, onTap,
  vehicleId: for AppHero continuity
)
```

Selected state is owned by the feature controller; the card only renders `selected`.

### 9.5 OTP recipe

Use `OTPInputRow(onCompleted: ..., onChanged: ...)` inside a `GlassCard`. Do not rebuild custom digit boxes.

### 9.6 Do / Don’t

| Do | Don’t |
|----|-------|
| Use `AppSpacing` / `AppRadius` / `AppColors` | Hardcode `EdgeInsets.all(16)` or `#FF6624` in features |
| Extend `lib/core/widgets` when a pattern repeats | Copy-paste glass containers into feature folders |
| Compose `AnimatedPrimaryButton` for main CTAs | Invent a second primary button style |
| Respect reduced-motion via existing primitives | Add unbounded looping Lottie without guidelines |
| Keep business logic in features / Riverpod | Put API or auth calls inside core widgets |

### 9.7 Where new shared UI should live

| Situation | Location |
|-----------|----------|
| Truly global, reference-faithful component | `lib/core/widgets/` |
| Theme token addition | `lib/core/theme/` |
| Motion primitive | `lib/core/animations/` |
| Feature-only one-off layout | `lib/features/<feature>/presentation/widgets/` |
| Cross-feature but not brand-primitive | Prefer elevating to `core` once reused twice |

`lib/shared/` remains reserved; **do not duplicate** core design-system widgets there.

---

## 10. Verification Status (at delivery)

| Check | Result |
|-------|--------|
| `flutter analyze` | No issues (after lint cleanup) |
| `flutter test` | Passed with `google_fonts 6.1.0` |
| Feature / auth / Firebase logic in core UI | None |
| Reference-driven tokens | Aligned with Phase 1 design docs |

---

## 11. Next Phase Expectations

Future phases (onboarding, auth screens, booking UI) should:

1. Import barrels above.
2. Assemble screens from these primitives only.
3. Add assets under registered `assets/` folders (`AssetPaths`).
4. Avoid introducing a parallel design language.
5. Update this document and `docs/design_system/WIDGETS.md` when new **global** components are added.

---

## 12. Document Control

| Field | Value |
|-------|-------|
| Phase | 02 — Global UI Foundation |
| Type | Documentation only (this file) |
| Code path | `idhar_udhar/lib/core/{theme,widgets,animations}` |
| Companion | `idhar_udhar/docs/design_system/WIDGETS.md` |
| Upstream specs | `16_Design_System.md`, `17_Animation_Guidelines.md`, `15_UI_UX_Guidelines.md` |
