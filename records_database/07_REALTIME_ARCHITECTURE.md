# REAL-TIME ARCHITECTURE

Do **not** poll every client every 10 seconds for everything. Use the right channel per workload.

## Channels

| Channel | Use |
|---|---|
| REST | CRUD, quotes, history lists, report fetches, settings |
| WebSocket (or SSE for admin metrics) | Order status, rider location while on a live job, incoming offer, live ops map |
| Push (FCM) | Background: offer, assigned, arriving, delivered, wallet, KYC |
| Short polling | Admin dashboard KPI cards **only as fallback** (~10s) if WS down |
| Queue + workers | Invoice PDF, emails, campaign fan-out, daily aggregates, payouts |
| Redis pub/sub | Fan-out WS events from workers |

Firebase is **not** the system of record. FCM (or equivalent) is an **outbound push** adapter.

---

## Feature matrix

| Feature | Producer | Consumer | Frequency | Channel | Why |
|---|---|---|---|---|---|
| Rider offer + 27s timer | Dispatch worker | Rider app | Burst | Push + WS | Must interrupt overlay; timer is server `expires_at` |
| Offer accept race | Rider | Order | Once | REST + row lock | Consistency > realtime |
| Order status | Rider/admin/system | Customer, Admin live, Rider | Per step | WS + push | Customer Tracking screen |
| Rider location | Rider GPS | Customer tracking, Admin map | 3–8s while **on trip** | WS (throttle) | High volume; store last point in Redis, sample to DB |
| Online/offline | Rider | Dispatch, Admin | On toggle + heartbeat 30–60s | REST + Redis presence | Cheap |
| Customer tracking | — | Customer | On screen | WS subscribe order | Don’t stream if app backgrounded; push instead |
| Payment status | Webhook | Customer/Admin | Rare | REST poll intent + WS event | Webhook is source |
| Wallet | Ledger worker | Owner | Rare | Push + REST | Not 10s poll |
| Notifications inbox | Worker | User | Event | Push + unread-count cache | Paginated REST for history |
| Admin dashboard KPIs | Aggregator 10–60s | Admin | ~10s product ask | SSE or poll **aggregates API** | Never rescan millions of orders in browser |
| Admin live operations | Location+status | Admin | Seconds | WS room `ops:{city}` | Filter by zone |
| Vehicle category change | Admin | Apps | Rare | REST GET on open + optional pub | Cache TTL 60s |
| Announcements | Admin | Rider/Customer | Rare | Push + REST | |

## Location scale

100k riders × 1 Hz = unsustainable. Rules:

- Send location **only if online and (on_trip or Admin tracking that rider)**.  
- Redis `rider:{id}:loc` TTL 30s.  
- Persist breadcrumb every Nth point or on status change.  
- Customer receives **assigned rider** location only.

## Dashboard “every 10 seconds”

Implement as: `GET /v1/admin/reports/overview?period=` hitting `daily_order_stats` + Redis cache 5–10s. Optional SSE heartbeat. **Forbidden:** client downloading full `orders[]` each tick (current Admin pattern).

## Reliability

- WS reconnect with last event id.  
- Push as backup when WS disconnected.  
- Exactly-once **business** via DB constraints; at-least-once notifications with `notification.id` dedupe on client.
