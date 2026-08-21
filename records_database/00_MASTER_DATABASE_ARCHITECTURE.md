# IDHAR UDHAR — MASTER DATABASE & SYSTEM ARCHITECTURE

**Status:** Discovery + architecture only. **No tables, APIs, app code, or deploys** in this run.  
**Wait for explicit approval** before schema, backend, mock replacement, or connecting apps.

**Current apps (2026-08-21 alignment):** `FINAL_MASTER_ANALYSIS.md`. Shared Dart/JS engines encode payment splitting, COD, cancellation, and resend. PostgreSQL is still **not built**.

**Customer discovery (existing, not rewritten):**  
`records_database/01_customer_database_discovery.md`  
(Windows: same file as `01_CUSTOMER_DATABASE_DISCOVERY.md`.)

---

## 0. What exists today

| App | Path | Data reality |
|---|---|---|
| Customer Flutter | `idhar_udhar/lib/customer` | Mock + SharedPreferences; dummy OTP |
| Rider Flutter | `idhar_udhar/lib/rider` | Dummy repository; OTP `123456` |
| Admin React | `IDHAR_UDHAR_ADMIN` | localStorage stores + mock JS |
| Shared catalog | `lib/shared/vehicle_category` | GET Admin Netlify `vehicle-categories` |
| Admin HTTP | `netlify/functions` | login/session + vehicle-categories blobs |

There is **no** shared production database. The three UIs will diverge unless a backend becomes the only writer.

---

## 1. Recommended database architecture

**PostgreSQL** = source of truth (relational orders, wallets, snapshots, RBAC).  
**Redis** = presence, last GPS, unread counts, short dashboard cache, rate limits, pub/sub.  
**Object storage** = KYC, POD, invoice PDFs.  
**Not Firebase DB.** FCM optional for push.

Managed Postgres with PITR backups, connection pooling (PgBouncer), UUID PKs + display IDs.

Details: `05_DATABASE_SCHEMA_BLUEPRINT.md`, `16_ARCHITECTURE_DECISIONS.md`.

---

## 2. Recommended backend architecture

Single **API + workers** (Node or equivalent) in front of Postgres.

```
Customer Flutter ──┐
Rider Flutter ─────┼── HTTPS /v1 + WebSocket ── API ── PostgreSQL
Admin React ───────┘         │                    │
                             │                    ├── Redis
                             │                    └── S3
                        FCM push
                             │
                    Queue workers: invoice, email, SMS, dispatch,
                    webhooks, daily_order_stats, campaigns
```

Admin `localStorage` and Flutter mocks remain until a later integration step (no UI rewrite now).

---

## 3. Real-time

WS for order/location/offers; push for background; **~10s Admin dashboard polls aggregate API** (not full order dump).  
See `07_REALTIME_ARCHITECTURE.md`.

---

## 4. Main production entities

Customer, Rider, AdminUser, VehicleCategory, Vehicle, CustomerAddress, Zone, ParcelCategory/Size, Order, OrderStop, OrderOffer, OrderStatusEvent, FareQuote, OrderFareSnapshot, PaymentSettingsVersion, OrderFinanceSnapshot, Payment, Wallet, WalletTransaction, Payout, Invoice, PurchaseInvoice, RiderDocument, RiderBank/UPI, Notification, Announcement, Coupon, Promotion, SupportTicket, Rating, ProofOfDelivery, AuditLog, DailyOrderStats, FileObject.

---

## 5. Financial architecture

Configurable percents with **version history**.  
`rider = ride × r%`, `commission = ride × c%` (r+c=100), `opex = commission × o%`, `profit = commission − opex`.  
**Immutable snapshot on each completed (and policy-defined cancelled) order.** Reports sum snapshots.  
See `08_PAYMENT_FINANCIAL_ARCHITECTURE.md`.

---

## 6. Order lifecycle (canonical)

created → searching → offered → assigned → en_route_pickup → arrived_pickup → picked_up → in_transit → near_drop → delivered  
also: cancelled | failed | offer_rejected (back to searching).

Mapping from three apps: `14_DATA_FLOW_CUSTOMER_RIDER_ADMIN.md`.

---

## 7. Synchronization model

All apps talk to API with **the same UUIDs**. No name joins. No cross-app local storage. Admin category/settings writes versioned rows; mobiles read IDs. Order events fan out over WS/push.

---

## 8. Reporting

Worker-maintained daily aggregates; Admin Today/Week/Month/Year and performance colors (green / light orange / red) from those APIs.  
`10_REPORTING_ARCHITECTURE.md`.

---

## 9. Notifications

Per-user paginated inbox + unread counter + FCM; Admin campaigns enqueue workers.  
`09_NOTIFICATION_ARCHITECTURE.md`.

---

## 10. Scaling

Day 1: indexes, cursors, pool, Redis, backups, workers.  
Later: read replica, partitions, archive. Not sharding on day 1.  
`16_ARCHITECTURE_DECISIONS.md` ADR-013.

---

## 11. Consistency patterns (critical)

| Risk | Solution |
|---|---|
| Two riders accept | DB lock + unique accepted offer |
| Category deleted in use | FK + deactivate-only (already Admin UX) |
| Settings change | new version; old snapshots untouched |
| Payment vs order | webhook + outbox; idempotency keys |
| Wallet vs order | single transaction or hold-then-capture |
| Duplicate notifications | notification id + client dedupe |
| Stale dashboard | cache aggregates 5–10s, not full tables |
| Invoice fail after pay | retry worker; payment remains paid |
| Client/Rider status drift | only backend transitions |

---

## 12. Validation checklist

1–4. Backend owns Customer/Rider/Admin entities; shared IDs.  
5. Vehicle categories UUID/VC-id, not names.  
6–8. Indexes for customer_id, rider_id, admin filters.  
9–13. Finance snapshot + versioned percents (85/15/50-of-commission).  
14. Reports from aggregates.  
15–16. Cursor notifications; throttled GPS + WS.  
17–18. Append-only wallet + payment.  
19. Invoice FK order.  
20. Audit log.  
21. PII/KMS/S3.  
22. No app-to-app local storage.  
23. Mocks not production.  
24. No name joins.  
25. History ≠ current settings.

---

## 13. Files in `records_database/`

| File | Role |
|---|---|
| `00_MASTER_DATABASE_ARCHITECTURE.md` | This index |
| `01_customer_database_discovery.md` | Customer (existing full report) |
| `02_RIDER_DATABASE_DISCOVERY.md` | Rider |
| `03_ADMIN_DATABASE_DISCOVERY.md` | Admin |
| `04_UNIFIED_ENTITY_RELATIONSHIPS.md` | ER |
| `05_DATABASE_SCHEMA_BLUEPRINT.md` | Tables |
| `06_API_CONTRACT_BLUEPRINT.md` | /v1 |
| `07_REALTIME_ARCHITECTURE.md` | WS/push/poll |
| `08_PAYMENT_FINANCIAL_ARCHITECTURE.md` | Money |
| `09_NOTIFICATION_ARCHITECTURE.md` | Inbox |
| `10_REPORTING_ARCHITECTURE.md` | KPI |
| `11_SECURITY_ARCHITECTURE.md` | Secrets/auth |
| `12_FILE_STORAGE_ARCHITECTURE.md` | S3 |
| `13_ROLE_PERMISSION_MATRIX.md` | RBAC |
| `14_DATA_FLOW_CUSTOMER_RIDER_ADMIN.md` | Lifecycle |
| `15_MOCK_TO_PRODUCTION_MAPPING.md` | Mapping |
| `16_ARCHITECTURE_DECISIONS.md` | ADRs |
| `17_OPEN_DECISIONS.md` | Unresolved |

---

**STOP.** Do not create the database or backend until approved.
