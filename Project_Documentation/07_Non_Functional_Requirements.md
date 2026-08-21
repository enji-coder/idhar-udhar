# 07 — Non-Functional Requirements

## 7.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-P-001 | Cold start to interactive splash complete | ≤ 3s on mid-range Android |
| NFR-P-002 | Booking funnel screen transitions | ≤ 200ms perceived (local) |
| NFR-P-003 | Fare estimate after locations set | ≤ 2s p95 |
| NFR-P-004 | Map tile + first location fix | ≤ 5s on good network |
| NFR-P-005 | Live location UI update interval | 3–5s when trip active |
| NFR-P-006 | List screens (history) first paint with cache | ≤ 500ms |
| NFR-P-007 | APK/IPA size budget | Monitor; use deferred components if needed |

## 7.2 Scalability

| ID | Requirement |
|----|-------------|
| NFR-S-001 | Architecture supports 1M+ registered users without schema redesign |
| NFR-S-002 | Firestore queries always indexed; avoid collection-group hotspots |
| NFR-S-003 | Rider location writes throttled; use geohash / geo queries carefully |
| NFR-S-004 | Cloud Functions region: prefer `asia-south1` for India latency |
| NFR-S-005 | Horizontal scale via Firebase managed services; no single VM bottleneck |

## 7.3 Reliability & Availability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-R-001 | Crash-free sessions | ≥ 99.5% |
| NFR-R-002 | Critical path (book + track) available | Align with Firebase SLA |
| NFR-R-003 | Graceful degradation when Maps/Places fail | Cached last location + retry |
| NFR-R-004 | Idempotent booking creation | Prevent duplicate bookings |

## 7.4 Security

| ID | Requirement |
|----|-------------|
| NFR-SEC-001 | All secrets in CI/env; never committed |
| NFR-SEC-002 | Firestore security rules deny by default |
| NFR-SEC-003 | OTP rate limiting / abuse protection |
| NFR-SEC-004 | TLS for all network calls |
| NFR-SEC-005 | PII minimized in analytics events |
| NFR-SEC-006 | Rider docs in Storage with restricted rules |
| NFR-SEC-007 | Jailbreak/root detection optional (V1.1) |

## 7.5 Usability & Accessibility

| ID | Requirement |
|----|-------------|
| NFR-U-001 | Primary CTAs ≥ 48dp touch targets |
| NFR-U-002 | Support Dynamic Type / textScaleFactor up to 1.3 without breaking layouts |
| NFR-U-003 | Color contrast AA for body text on glass backgrounds (navy on white/cream) |
| NFR-U-004 | Empty, loading, and error states for every data screen |
| NFR-U-005 | Consistent glassmorphism language across auth & onboarding |

## 7.6 Maintainability

| ID | Requirement |
|----|-------------|
| NFR-M-001 | Feature-first folder structure |
| NFR-M-002 | Freezed models; no hand-written JSON maps in UI |
| NFR-M-003 | Riverpod providers typed and layered (data → domain → presentation) |
| NFR-M-004 | Lints + format enforced in CI |
| NFR-M-005 | Shared design system package for both apps |

## 7.7 Observability

| ID | Requirement |
|----|-------------|
| NFR-O-001 | Crashlytics enabled in production builds |
| NFR-O-002 | Key funnel analytics events defined |
| NFR-O-003 | Structured error codes mapped to user messages |
| NFR-O-004 | Performance traces for fare estimate & matching |

## 7.8 Offline & Network

| ID | Requirement |
|----|-------------|
| NFR-N-001 | Read-mostly screens work from Hive/Firestore cache |
| NFR-N-002 | Mutations queue or fail clearly when offline |
| NFR-N-003 | No silent data loss; conflict strategy documented |

## 7.9 Localization & i18n Readiness

| ID | Requirement |
|----|-------------|
| NFR-L-001 | All user strings via ARB / l10n from day one (English) |
| NFR-L-002 | Currency formatting for INR |
| NFR-L-003 | Date/time via locale-aware formatters |

## 7.10 Compliance & Privacy

| ID | Requirement |
|----|-------------|
| NFR-C-001 | In-app privacy copy matches actual location usage |
| NFR-C-002 | Consent for notifications where required |
| NFR-C-003 | Document retention policy for KYC images (ops-defined) |
