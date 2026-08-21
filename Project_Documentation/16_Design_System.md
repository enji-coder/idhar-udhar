# 16 — Design System

## 16.1 Source Analysis Summary

Extracted from attached logo and UI references (splash, onboarding 1–3, login, registration, OTP, forgot password, location permission).

| Category | Observation |
|----------|-------------|
| Design language | Premium glassmorphism + warm logistics realism / 3D illustration |
| Primary action color | Vibrant orange |
| Trust / text color | Deep navy |
| Surfaces | Frosted translucent white cards |
| Buttons | Pill-shaped orange gradients with arrow |
| Radii | Large (20–40dp cards; full pill CTAs) |
| Imagery | Sunset city, orange-branded vehicles, parcels |

## 16.2 Color Tokens

### Brand Core

| Token | Hex | Usage |
|-------|-----|-------|
| `color.brand.orange` | `#FF6624` | IDHAR wordmark, accents, icons, active states |
| `color.brand.orange.pressed` | `#E55A1F` | Pressed primary |
| `color.brand.orange.soft` | `#FF8A4A` | Gradient end / highlights |
| `color.brand.navy` | `#2E4072` | UDHAR wordmark, logo body, headings |
| `color.brand.navy.deep` | `#1A2B4C` | High-emphasis body / secondary buttons |

### Semantic

| Token | Hex | Usage |
|-------|-----|-------|
| `color.success` | `#22A06B` | Delivered, success checks |
| `color.warning` | `#F5A524` | Pending KYC |
| `color.danger` | `#E11D48` | Errors, destructive |
| `color.info` | `#3B82F6` | Informational |

### Neutrals & Surfaces

| Token | Hex / Value | Usage |
|-------|-------------|-------|
| `color.surface.cream` | `#FFF7F0` | Soft onboarding backgrounds |
| `color.surface.white` | `#FFFFFF` | Solid surfaces |
| `color.surface.glass` | `#FFFFFF` @ 55–75% | Frosted cards |
| `color.text.primary` | `#1A2B4C` | Titles, body |
| `color.text.secondary` | `#5C6B8A` | Captions |
| `color.text.inverse` | `#FFFFFF` | On orange buttons |
| `color.border.glass` | `#FFFFFF` @ 40–70% | Card edge stroke |
| `color.border.subtle` | `#E6EAF2` | Input borders on light BG |
| `color.overlay.scrim` | `#1A2B4C` @ 40% | Modals |

### Gradients

| Token | Definition | Usage |
|-------|------------|-------|
| `gradient.cta.primary` | `#FF8A4A` → `#FF6624` (or deeper `#FF4D00`) horizontal | Primary buttons |
| `gradient.cta.navyOrange` | `#2E4072` → `#FF6624` | Alternate onboarding Next (screen1 style) |
| `gradient.sunset.bg` | Soft peach → warm gold → lavender edges | Auth backgrounds (prefer image) |
| `gradient.glow.orange` | Radial soft orange | Button/card outer glow |

## 16.3 Typography

**Family:** Google Fonts **Poppins** (primary). Fallback: Montserrat if Poppins unavailable.

| Token | Size / Weight | Usage |
|-------|---------------|-------|
| `type.display` | 28–32 / Bold | Onboarding hero headlines |
| `type.h1` | 24–26 / Bold | Auth titles |
| `type.h2` | 20 / SemiBold | Section titles |
| `type.h3` | 16–18 / SemiBold | Card titles |
| `type.body` | 14–15 / Regular–Medium | Descriptions |
| `type.label` | 12–13 / Medium | Field labels |
| `type.caption` | 11–12 / Regular | Fine print, privacy |
| `type.button` | 16 / SemiBold | CTA labels |
| `type.otp` | 20–22 / Bold | OTP digits |

**Wordmark:** All-caps geometric sans; **IDHAR** orange, **UDHAR** navy.

**Headline color mixing:** Primary phrase navy; emphasis word orange (e.g., “Forgot **Password?**”).

## 16.4 Spacing Scale

`4, 8, 12, 16, 20, 24, 32, 40, 48, 64`

Card inner padding: **20–28**. Screen horizontal margin: **20–24**.

## 16.5 Radius Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `radius.sm` | 12 | Chips, small cards |
| `radius.md` | 16–20 | Inputs, floating info cards |
| `radius.lg` | 24–28 | Medium glass panels |
| `radius.xl` | 32–40 | Main auth glass cards |
| `radius.pill` | 999 | Primary buttons, skip chips |
| `radius.otp` | 12–16 | OTP cells |

## 16.6 Shadows & Elevation

| Token | Spec | Usage |
|-------|------|-------|
| `shadow.card` | 0 8 24 rgba(26,43,76,0.10) | Glass cards |
| `shadow.float` | 0 4 16 rgba(26,43,76,0.08) | Onboarding info chips |
| `shadow.cta` | 0 10 24 rgba(255,102,36,0.35) | Primary button glow |
| `shadow.soft` | 0 2 8 rgba(0,0,0,0.06) | Inputs |

## 16.7 Glass Effects

| Property | Guidance |
|----------|----------|
| Blur | Backdrop blur **16–24** |
| Fill | White 55–75% opacity |
| Border | 1px white 40–70% |
| Shape | Large rounded rect |
| Content | Prefer navy text; avoid low-contrast gray |

Implement via `BackdropFilter` + translucent decoration; provide solid cream fallback when blur is too costly on low-end devices.

## 16.8 Components

### Buttons

- **Primary:** Pill, `gradient.cta.primary`, white text, optional trailing circular arrow
- **Secondary:** Text / ghost navy
- **Social:** White/glass rounded rect with brand mark
- **Skip:** Compact pill, light fill, small arrow

### Inputs

- Height ~52–56
- Leading outline icon in orange
- Trailing: eye toggle, +91 dropdown
- Focus: orange border / soft glow
- Error: danger border + caption

### Cards

- Glass auth card
- Vehicle selection: vertical cards; selected = orange border + check
- Trust nested glass footer
- Feature list rows with orange circular icon wells

### Icons

- Outline / line-art in forms (1.5–2 stroke)
- Solid orange for instructional wells
- Trust: shield, lock, pin, clock in navy line style

### Navigation Chrome

- Dot indicators: inactive soft gray; active orange
- iOS-style status bar on light/dark adaptive

## 16.9 Motion Tokens (Cross-ref 17)

| Token | Duration | Curve |
|-------|----------|-------|
| `motion.fast` | 150ms | easeOut |
| `motion.normal` | 250–300ms | easeInOut |
| `motion.enter` | 400ms | easeOutCubic |
| `motion.page` | 350ms | easeInOut |

## 16.10 Logo Usage

- Clear space ≥ 0.5× mark height
- Prefer full color on dark or photographic backgrounds
- Do not recolor the mark arbitrarily
- Splash: mark above wordmark + tagline “Delivering Trust, Every Time”

## 16.11 Material 3 Mapping

Use M3 as the **component behavior** foundation (ripples, scaffolds) but **override** colorScheme and shapes to brand tokens. Do not ship default M3 purple seed.

```
primary = orange
onPrimary = white
secondary = navy
surface = cream/white
```

## 16.12 Asset Pipeline

- Export logo SVG/PNG @ 1x/2x/3x
- Auth backgrounds: compressed WebP
- Lottie: truck loader, success check (subtle)
- Cache network images for rider photos
