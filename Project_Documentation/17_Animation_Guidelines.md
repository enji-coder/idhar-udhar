# 17 — Animation Guidelines

## 17.1 Motion Philosophy

Motion should create **presence and hierarchy**, not noise. Prefer soft fades, gentle slides, and glowing CTA feedback that match glassmorphism—avoid chaotic particles or long decorative loops.

## 17.2 Intentional Motions (Minimum Set)

Ship at least these brand motions:

1. **Splash progress** — Determinate/indeterminate bar fill in brand orange; optional subtle truck Lottie.
2. **Glass card enter** — Fade + slight upward slide (24→0) on auth screens.
3. **CTA press** — Scale 0.98 + shadow intensify; release spring back.
4. **Onboarding page change** — Shared-axis horizontal; dots morph active size/color.
5. **Selection select** — Orange border + check pop (scale-in).
6. **OTP digit entry** — Cell highlight glow pulse once on focus.
7. **Success** — Soft check Lottie on delivery/payment success (≤ 1.2s).

## 17.3 Timing & Easing

| Use | Duration | Curve |
|-----|----------|-------|
| Micro (icons, checks) | 120–180ms | easeOut |
| Component | 200–300ms | easeInOut |
| Screen enter | 300–450ms | easeOutCubic |
| Page route | 300–350ms | easeInOut |
| Skeleton shimmer | 1000–1500ms loop | linear |

Respect `MediaQuery.disableAnimations` / reduced motion: replace with fades or instant swaps.

## 17.4 Route Transitions (GoRouter)

- Auth stack: fade-through
- Onboarding: horizontal shared axis
- Booking funnel: horizontal slide
- Modal sheets: vertical open
- Tracking: fade (map heavy)

## 17.5 Lottie Usage Policy

| Allowed | Not allowed |
|---------|-------------|
| Splash loader | Full-screen looping distractions |
| Empty states (subtle) | Autoplay sound |
| Success moments | Multiple Lotties competing |

Cap file size; prefer single-color-friendly animations that accept orange/navy theming where possible.

## 17.6 Map & Live Tracking Motion

- Smooth animate camera to rider updates (throttle)
- Polyline draw once; avoid redraw thrash
- ETA text crossfade on change

## 17.7 Performance Rules

- No backdrop blur animation every frame on low-end (static blur)
- Prefer `AnimatedOpacity` / `AnimatedSlide` over heavy custom painters
- Dispose controllers; stop Lottie offscreen
- 60fps target on mid-range; degrade effects before dropping frames

## 17.8 Haptics (Optional)

- Light impact on primary CTA
- Success haptic on OTP verify / delivery confirm
- Never spam haptics on scroll
