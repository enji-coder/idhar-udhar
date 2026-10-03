# IDHAR UDHAR — Production Readiness Log

**Branch:** `main`  
**Baseline commit:** `4605d43` — fix: package production migrations in backend image  
**Working tree:** dirty (hardening in progress on existing local changes)  
**Updated:** 2026-10-03  

Status values: `DONE` | `PARTIAL` | `FAILED` | `BLOCKED` | `NOT_STARTED`

| Feature | Status | What was checked | Changes made | Tests | Failure/Blocker |
| ------- | ------ | ---------------- | ------------ | ----- | --------------- |
| PHASE 1 Architecture audit | DONE | Orders/dispatch/payments/wallet/FCM/location | Log created | n/a | Do not commit `API_KEY.txt` |
| Customer booking create/quote/confirm | DONE | Real APIs; quote reuse via hold | Unchanged happy path | Flutter fare 14 pass | — |
| Payment responsibility/plan on confirm | PARTIAL | Existing Nest APIs; SEARCHING not gated on prepaid | Wired after confirm in `booking_api.dart` | Manual path | ONLINE Cashfree trip session still not auto-opened |
| Automatic SYSTEM dispatch | DONE | Confirm → SEARCHING → offers | Already present | dispatch-after-confirm | No geo radius (by design) |
| Redispatch after reject/expire | DONE | Last reject → SEARCHING stuck | `rejectOffer` + expire-accept commit then redispatch | redispatch-after-reject | — |
| Rider offer accept/reject | DONE | Locks + idempotency; expire TX fix | Expire commits before 409 | unit | — |
| Finance 85/15 on DELIVERED | DONE | Was admin-only freeze | `FinanceService.captureOnDelivered` in DELIVERED TX + wallet sync | finance-delivered | — |
| Trip ONLINE prepaid before search | BLOCKED | Would change architecture | Not implemented | n/a | BUSINESS DECISION — keep SEARCHING after confirm |
| Waiting receivable / Cashfree clearance | DONE | Existing path | Unchanged | payment specs | Needs live Cashfree env |
| Wallet/COD backend | DONE | Ledger + suspend ₹100 | Synced via captureOnDelivered | wallet specs | — |
| Local Flutter wallet mutation | DONE | `completeRiderTrip` / `applyRiderEarning` | Removed local credit/debit; refresh server wallet | — | — |
| FCM token registration plumbing | PARTIAL | DeviceTokensApi unused | `PushTokenSync` on login/logout | — | BLOCKED on Firebase project / FlutterFire config |
| Customer live rider location | DONE | Rider publish only | `GET /v1/orders/:id/rider-location` + tracking marker | rider-location-read | Needs rider publishing GPS |
| Tracking cancel API | DONE | Was local-only | Calls `orders.cancel` | — | — |
| Session seedOrders demo | DONE | Fake history | Start with empty orders | — | MockData catalogs remain for UI labels |
| Admin ops / mock campaigns | PARTIAL | Static notifications/verification | Deferred | — | Cleanup remaining |
| AWS / secrets / rate limit | NOT_STARTED | — | Deferred Phases 9–10 | — | No destructive AWS changes |
| Geo-radius dispatch | BLOCKED | Product decision | Not invented | n/a | BUSINESS DECISION REQUIRED |

## Business decisions preserved

1. **No payment-before-SEARCHING** — responsibility/plan persisted after confirm; SEARCHING/dispatch continue.
2. **No geo-radius matching** — eligible ONLINE broadcast (category/vehicle/live-order/COD rules) retained.
3. **85/15 from Trip Fare only** — freeze uses fare snapshot via existing SQL allocate path.

## Secrets

- Do **not** commit `API_KEY.txt`, Cashfree, Firebase, or AWS credential files.
