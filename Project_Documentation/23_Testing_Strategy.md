# 23 — Testing Strategy

## 23.1 Test Pyramid

| Layer | Scope | Tooling |
|-------|-------|---------|
| Unit | Notifiers, use cases, mappers, fare pure logic | `flutter_test`, mocktail |
| Widget | Design system components, form validation UI | `flutter_test` |
| Golden | Buttons, glass cards, OTP cells | golden_toolkit (optional) |
| Integration | Auth → home smoke | `integration_test` |
| Functions | Matching transactions, coupons | Jest / mocha for Node |
| Manual / UAT | Device matrix, maps, payments | QA checklists |

## 23.2 Mandatory Coverage Areas (MVP)

- Auth validation & error mapping
- Booking draft state transitions
- Fare calculation pure functions (client mirror of server rules for display only)
- GoRouter redirects (auth/KYC)
- Coupon edge cases (server tests authoritative)
- Rider accept race (Function tests)

## 23.3 What Not to Over-Test

- Pixel-perfect glass blur across OS versions
- Third-party SDK internals (Maps)

## 23.4 Test Data

- Firebase Emulator seed scripts
- Fixture JSON for bookings
- Fake Geolocator positions

## 23.5 CI Gates

- `dart analyze` / `flutter analyze` zero errors
- Unit + widget tests pass
- Format check
- (Optional) coverage threshold on `iu_domain` / fare logic

## 23.6 Device Matrix (Manual)

| Platform | Devices |
|----------|---------|
| Android | Mid-range + low-end |
| iOS | Latest + one prior major |
| Networks | Wi-Fi, 4G, airplane toggle mid-flow |

## 23.7 Acceptance Testing

Each Development Phase ends with a UAT checklist mapped to Functional Requirements IDs.
