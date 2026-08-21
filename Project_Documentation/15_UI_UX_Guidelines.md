# 15 — UI/UX Guidelines

## 15.1 Design Intent

IDHAR UDHAR should feel **premium, trustworthy, and energetic**—glassmorphic surfaces over warm logistics imagery, never generic purple SaaS or flat enterprise gray.

Derived from provided references: splash, onboarding (3), login, registration, OTP, forgot password, location permission, and brand logo.

## 15.2 Experience Principles

1. **Brand first** — Logo and wordmark are hero signals on splash/auth; headlines never overpower the brand.
2. **One job per screen** — Onboarding and auth cards focus on a single action.
3. **Trust visible** — Shields, encryption copy, privacy footers on permission & OTP screens.
4. **Action in orange** — Primary CTAs use orange gradients; navy for stable text.
5. **Glass over life** — Forms float on real delivery photography/illustration, not empty flats.
6. **Honest status** — Loading bars, OTP timers, searching states always visible.

## 15.3 Screen Patterns

### Splash

- Centered logo + wordmark + tagline
- Hero truck / logistics visual
- Progress bar + “Loading…”
- Value line: Fast. **Safe.** Reliable.

### Onboarding Carousel

- 3 pages with Skip
- Mixed navy/orange headlines
- Bottom sheet or glass footer with Next / Back / Get Started
- Dot indicators (active = orange, larger)

### Auth (Login / Register / Forgot / OTP)

- Sunset city + branded vehicles background
- Frosted glass card, large radius
- Split-color titles (“Welcome **Back!**”, “Create Your **Account**”, “Forgot **Password?**”, “Verify Your **Number**”)
- Pill primary button with trailing arrow
- Social buttons as secondary glass/white chips (V1.1)
- Bottom page dots when part of intro sequence

### Location Permission

- Illustrative map/city hero
- Glass card with benefit list + chevrons
- Primary “Allow Location”; secondary “Not Now”
- Nested privacy glass footer

### Booking / Ops Screens (to extend language)

- Keep cream/off-white or map-first canvases
- Selection cards with orange border + check when selected
- Same primary button language
- Avoid introducing a second unrelated visual system

## 15.4 Interaction Patterns

| Pattern | Behavior |
|---------|----------|
| Primary CTA | Full-width pill, orange gradient, white label, arrow affordance |
| Secondary | Text button navy with chevron |
| Skip | Small pill, low emphasis, top-end |
| Inputs | Rounded, leading icon (orange), optional trailing (+91, eye) |
| Checkbox | Custom orange filled when on |
| Selection cards | Orange stroke + check badge when selected |
| OTP boxes | 6 cells; active = orange glow border |
| Page dots | Active orange elongated/larger |

## 15.5 Content Tone

- Short, confident, India-friendly English
- Emphasize safety and speed without fearmongering
- Error copy: specific + recoverable (“OTP expired. Resend to try again.”)

## 15.6 Layout & Spacing

- Generous padding inside glass cards (20–28dp)
- Vertical form rhythm: 12–16dp between fields
- Safe areas respected; home indicator clearance
- Responsive Framework breakpoints for tablets (scaled padding, not desktop redesign)

## 15.7 Accessibility UX

- Don’t rely on color alone for selection (check icon required)
- Maintain readable navy text on frosted white (avoid light gray on glass)
- Motion can be reduced when `disableAnimations` / OS setting

## 15.8 Do / Don’t

| Do | Don’t |
|----|-------|
| Use brand sunset imagery & glass | Flat purple gradients / generic AI aesthetics |
| Mix navy + orange in headlines | All-orange walls of text |
| Show privacy rationale before OS prompt | Jump straight to system dialog |
| Keep cards highly rounded | Sharp 4dp Material defaults for brand screens |
| Use Lottie sparingly for loaders | Infinite noisy particle effects |
