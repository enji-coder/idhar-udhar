# 28 — Risk Assessment

## 28.1 Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|------------|--------|------------|
| R1 | Maps/Places cost overrun | M | H | Session tokens; cache; budget alerts; restrict keys |
| R2 | Matching latency / no riders | H | H | Expand radius; timeout UX; supply seeding in pilot |
| R3 | Firestore location write costs | M | H | Throttle; evaluate RTDB later |
| R4 | KYC fraud / fake docs | M | H | Manual review MVP; future OCR/face match |
| R5 | Accept race double-assign | M | H | Transactional Function |
| R6 | Glass blur jank on low-end | H | M | Adaptive quality; solid fallback |
| R7 | OTP SMS delivery failures | M | H | Provider redundancy; clear resend UX |
| R8 | Scope creep (Admin early) | H | M | Strict MVP scope; change control |
| R9 | Play/App Store rejection | M | H | Privacy nutrition labels; location disclosure |
| R10 | Key leakage in client | M | H | Restricted keys; proxy sensitive calls |
| R11 | Payment disputes (cash) | H | M | Clear fare UI; rider confirm; support tickets |
| R12 | Single-region Firebase outage | L | H | Status page comms; retry; multi-region later |
| R13 | Team bus factor | M | M | Docs, pairing, code owners |
| R14 | Legal/compliance gaps | M | H | Counsel review before public launch |

## 28.2 Top Risks Before Coding Starts

1. Confirm auth approach (Phone Auth vs custom OTP)
2. Confirm payment MVP (cash-only vs online required)
3. Confirm launch city & vehicle catalog
4. Confirm Google Cloud billing & Maps quotas
5. Confirm KYC document list required by ops/legal

## 28.3 Monitoring Triggers

- Crash-free < 99% → hotfix train
- Matching success < 70% in peak → supply/ops intervention
- Daily Firebase spend > budget threshold → page on-call
