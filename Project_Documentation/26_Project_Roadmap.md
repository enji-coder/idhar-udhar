# 26 — Project Roadmap

## 26.1 Timeline Overview (Indicative)

Assumes a small cross-functional team (2–4 Flutter engineers, 1 backend/Firebase, 1 design, 1 QA/PM). Adjust after capacity validation.

| Milestone | Window | Outcome |
|-----------|--------|---------|
| M0 Documentation Sign-off | Week 0 | This package approved |
| M1 Foundation | Weeks 1–3 | Monorepo, design system, Firebase skeleton |
| M2 Auth & Onboarding | Weeks 4–6 | Customer + Rider auth UX complete |
| M3 Booking MVP | Weeks 7–11 | Customer can book & pay cash |
| M4 Rider Ops | Weeks 8–12 | Parallel: KYC, online, accept, navigate, confirm |
| M5 Tracking & Notifications | Weeks 12–14 | Live map + FCM |
| M6 Hardening | Weeks 15–17 | Performance, security, UAT |
| M7 Pilot Launch | Week 18 | 1 city soft launch |
| M8 V1.1 | Weeks 19–24 | Online pay, chat, social login, admin start |

Phases may overlap (Customer booking + Rider ops parallelized).

## 26.2 Milestone Exit Criteria

### M1

- Apps run with flavors
- Design tokens implemented in `iu_design_system`
- Emulators documented

### M2

- Register/login/OTP/forgot flows working against Firebase
- Onboarding + location permission screens match design language

### M3–M4

- End-to-end trip: book → accept → pickup → drop → cash paid → rate

### M5

- Live location updates on customer map
- Push for all critical events

### M6

- Crash-free ≥ 99% on beta
- Security rules reviewed
- Store listing assets ready

### M7

- Pilot city geofence live
- Ops runbook for KYC approvals

## 26.3 Dependency Critical Path

```
Design system → Auth UI → Location → Maps → Fare → Booking
                                      ↘ Matching → Rider trip → Tracking
Firebase Auth → Claims → Rules → Functions
```

## 26.4 Release Train

- Internal: weekly
- Closed beta: bi-weekly after M5
- Production: tagged releases only
