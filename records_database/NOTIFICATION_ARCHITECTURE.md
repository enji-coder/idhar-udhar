# IDHAR UDHAR — NOTIFICATION ARCHITECTURE

**Type:** Phase 6 implementation architecture  
**Date:** 2026-08-25  
**Does not modify:** `MASTER_SYSTEM_ARCHITECTURE.md`, PostgreSQL schema, Flutter, Admin UI  

Master §28 remains the rule authority. This file describes the running NestJS notification inbox, delivery outbox, and PostgreSQL-backed worker.

Production FCM (or equivalent) is **not** integrated. Push is provider-ready only.

---

## Simple business meaning

The system can say “something important happened” without each controller sending messages itself.

```text
Business event (order / payment / wallet / COD)
        ↓
NotificationService
        ↓
notifications row  (inbox fact)
        ↓
notification_deliveries  (IN_APP and/or PUSH)
        ↓
worker
        ↓
IN_APP marked SENT  ·  PUSH sent through PushProvider (or left PENDING/FAILED)
```

Notifications are **output only**. They never change order state, credit/debit wallet, settle COD, mark payment paid, or assign a rider.

---

## Tables used (existing schema)

No new tables. No migrations.

| Table | Role |
|---|---|
| `notifications` | Persisted inbox. PK is also the dedupe id. Unread = `read_at IS NULL`. |
| `notification_preferences` | Per-identity `in_app_enabled` / `push_enabled` (defaults true). |
| `notification_deliveries` | One row per `(notification_id, channel)`. Outbox for the worker. |

Recipient model (already in schema):

- `recipient_identity_id` required
- typed profile FK: `CUSTOMER` / `RIDER` / `ADMIN` with the matching `*_profile_id`

Optional `order_id` references the order when the event is about a trip. Bodies use `display_id` (for example `IU-AMD-0000000001`). Phones, tokens, and secrets are never stored in notification payloads.

---

## Lifecycle

```text
1. Domain service commits a business fact
2. Same DB transaction (where the event is authoritative):
     NotificationService.notify()
       · validate recipient
       · load / create preferences
       · INSERT notification (or reuse existing PK)
       · INSERT IN_APP delivery  PENDING or SKIPPED
       · INSERT PUSH delivery    PENDING or SKIPPED
3. API request returns. No HTTP call to a push vendor.
4. Worker later:
     SELECT … FOR UPDATE SKIP LOCKED
     IN_APP → SENT
     PUSH   → PushProvider.send()
              ok     → SENT + provider_message_id
              fail   → PENDING (retry) or FAILED
```

If the preference for a channel is off, that delivery is created as `SKIPPED` immediately. The worker does not process `SKIPPED`.

---

## In-app

Server-authoritative inbox.

| Action | Behavior |
|---|---|
| Create | Domain dispatchers call `NotificationService`. Clients cannot POST a notification for someone else. |
| List | Session identity **and** active profile type/id. Cursor pagination. |
| Unread count | Same session filter, `read_at IS NULL`. |
| Mark read | Sets `read_at` once (`COALESCE`). Wrong owner → 404. |
| Mark all read | Same session filter. |

Query `?identity_id=` is **ignored**. Recipient is always the authenticated session.

A customer session cannot read rider-inbox rows even if the same human owns both profiles. Inbox is scoped by `recipient_identity_id` + `recipient_profile_type` + matching profile FK.

---

## Preferences

Table unique on `identity_id`. Flags:

- `in_app_enabled`
- `push_enabled`

No extra mute-by-event-type categories.

GET/PUT `/v1/notification-preferences` uses the authenticated identity. There is no admin “edit someone else’s preferences” API in this phase; admin uses the same session-scoped endpoints for their own identity.

Preferences decide whether a **new** delivery is `PENDING` or `SKIPPED`. They do not rewrite historical deliveries.

---

## Delivery records

Channels (schema lock): `IN_APP` | `PUSH`  
Statuses (schema lock): `PENDING` | `SENT` | `FAILED` | `SKIPPED`

Unique `(notification_id, channel)` — at most one delivery row per channel per notification.

Fields used by the worker:

- `attempt_count` — incremented on claim
- `last_attempt_at` — claim / retry clock
- `last_error` — truncated, never tokens
- `provider_message_id` — capture id or null; **not** FCM confirmation

---

## Push abstraction

```text
PushProvider
  send(message) → { ok, providerMessageId } | { ok: false, error }
```

| Mode | Env | Behavior |
|---|---|---|
| `capture` | `PUSH_PROVIDER=capture` | In-memory sink. Local/tests. Does not mean a device received a push. |
| `unconfigured` | `PUSH_PROVIDER=unconfigured` (production default if unset) | Always fails honestly: “push provider is not configured”. |

No FCM SDK. No vendor secrets. Capture `provider_message_id` is an internal test handle, not a production receipt.

Controllers never call `PushProvider`. Only the worker does.

---

## Worker

PostgreSQL-backed (Redis is not required for this phase). Compatible with Master worker intent: durable outbox, later vendor send.

Claim:

```sql
SELECT … FROM notification_deliveries
WHERE status = 'PENDING'
  AND (last_attempt_at IS NULL OR last_attempt_at <= now() - backoff)
ORDER BY created_at, notification_delivery_id
FOR UPDATE SKIP LOCKED
LIMIT 1
```

Then `attempt_count = attempt_count + 1`.

Two workers cannot process the same delivery at once: the row lock plus `SKIP LOCKED` gives the second worker a different row (or none).

IN_APP success does not call a vendor. It marks `SENT` in the same claim transaction.

PUSH success/failure is recorded on the delivery row. A failed push **does not** roll back the original order/payment/wallet transaction — that transaction already committed.

There is **no** public “run worker” endpoint. Tests call `NotificationWorkerService.processBatch()` in-process.

E2E tests disable the interval loop (`NOTIFICATION_WORKER_ENABLED=false`) so batches are deterministic.

---

## Retry

Not infinite. Ceiling is environment configuration, **not** a locked product rule:

| Variable | Development default |
|---|---|
| `NOTIFICATION_MAX_ATTEMPTS` | 5 |
| `NOTIFICATION_RETRY_BACKOFF_SECONDS` | 2 |
| `NOTIFICATION_WORKER_POLL_MS` | 5000 |
| `NOTIFICATION_WORKER_BATCH_SIZE` | 20 |

On provider failure:

- `attempt_count < max` → stay `PENDING`, store `last_error`, wait backoff
- `attempt_count >= max` → `FAILED`, store `last_error`

Failed rows remain in the table for audit. The worker does not delete them.

---

## Idempotency

`idempotency_keys.scope` has no `notification` value. This phase does **not** add a scope (that would be a migration).

Dedupe uses the existing unique PK:

```text
eventKey  →  UUID v5 (fixed namespace)  →  notifications.notification_id
```

Same logical event (same key) inserts once. A second call returns `created: false` and does not duplicate the inbox row. Delivery inserts use `ON CONFLICT (notification_id, channel)` so channels are not duplicated either.

Example keys:

```text
order:{orderId}:ORDER_RIDER_ASSIGNED:CUSTOMER:{customerProfileId}
offer:{offerId}:OFFER_NEW:RIDER:{riderProfileId}
payment:{transactionId}:PAYMENT_SUCCESSFUL:CUSTOMER:{customerProfileId}
wallet:{sourceTxnId}:WALLET_RECHARGE_COMPLETED:RIDER:{riderProfileId}
cod-status:{riderProfileId}:SUSPENDED:{sourceTxnId}
```

---

## Authorization

| Actor | Inbox |
|---|---|
| Customer | Own customer-profile notifications only |
| Rider | Own rider-profile notifications only |
| Admin | Own admin-profile notifications only |

No client-supplied recipient id overrides the session. Mark-read on another user’s id returns **404** (not the other inbox).

Staff RBAC cells for “which admin should see which operational event” are **not** invented here. Cancelled / failed-delivery admin fan-out currently notifies **all active admin profiles**. Targeting by module remains a business decision.

---

## Failure behavior

| Failure | Business operation | Delivery |
|---|---|---|
| Push provider down / unconfigured | Already committed SUCCESS | `PENDING` then retry, or `FAILED` after max attempts |
| Preference off | SUCCESS | Channel `SKIPPED` |
| Recipient missing | Notify helper no-ops (`notifyIfRecipient`) | No row |

Never: “order succeeded but notification row missing” when the dispatcher ran in the same transaction.  
Never: “roll back cash collection because FCM timed out” — FCM is not called on the request path.

---

## Structured types

Templates live in one module (`backend/src/notifications/templates.ts`). Controllers do not scatter copy.

| Type | Typical audience |
|---|---|
| `ORDER_CONFIRMED` | Customer (`CREATED` → `SEARCHING` only) |
| `ORDER_RIDER_ASSIGNED` | Customer |
| `ORDER_RIDER_REACHED_PICKUP` | Customer |
| `ORDER_PICKED_UP` | Customer |
| `ORDER_OUT_FOR_DELIVERY` | Customer |
| `ORDER_DELIVERED` | Customer / rider |
| `ORDER_CANCELLED` | Customer / rider / admin |
| `ORDER_FAILED_DELIVERY` | Customer / rider / admin |
| `ORDER_ASSIGNED` | Rider |
| `OFFER_NEW` | Rider |
| `OFFER_EXPIRED` | Rider |
| `OFFER_CANCELLED` | Rider |
| `PAYMENT_SUCCESSFUL` | Customer (authoritative `PAID` transaction) |
| `PAYMENT_FAILED` | Customer (authoritative `FAILED` transaction) |
| `PAYMENT_REFUND_RECORDED` | Customer (`REFUNDED`) |
| `WALLET_RECHARGE_COMPLETED` | Rider |
| `COD_SETTLEMENT_COMPLETED` | Rider |
| `COD_SUSPENDED` | Rider (`SUSPENDED_FOR_COD`) |
| `COD_ELIGIBLE` | Rider (Due cleared back to `CLEAR`) |

---

## Order integration

`OrderNotificationDispatcher` reacts to existing `OrderStateMachine` transitions and offer rows. No new order states.

- Confirm (`CREATED` → `SEARCHING`) → customer `ORDER_CONFIRMED`. Returning to `SEARCHING` after an offer reject does **not** re-notify confirm.
- Assign → customer `ORDER_RIDER_ASSIGNED` + rider `ORDER_ASSIGNED`
- Pickup / transit / delivered / cancelled / failed → matching types
- New offer → rider `OFFER_NEW`
- Expired / taken offers → `OFFER_EXPIRED` / `OFFER_CANCELLED`

---

## Payment integration

`PaymentNotificationDispatcher` runs after an authoritative `payment_transactions` insert, inside the payment transaction.

| Transaction | Notify? |
|---|---|
| CASH CHARGE `PAID` | `PAYMENT_SUCCESSFUL` |
| ONLINE CHARGE `PENDING` | **No** (no fake capture) |
| `FAILED` | `PAYMENT_FAILED` |
| `REFUNDED` | `PAYMENT_REFUND_RECORDED` |

85/15, fare, and payment calculations are unchanged.

---

## Wallet / COD integration

`WalletNotificationDispatcher` reacts to existing Phase 5 outcomes. Wallet/COD services remain the financial authority.

| Event | Type |
|---|---|
| Wallet recharge remainder credited | `WALLET_RECHARGE_COMPLETED` |
| COD Due reduced by settle / settle-first recharge | `COD_SETTLEMENT_COMPLETED` |
| Operational status becomes `SUSPENDED_FOR_COD` | `COD_SUSPENDED` |
| Operational status returns `CLEAR` | `COD_ELIGIBLE` |

Reads (`GET` wallet / COD) do not notify.

₹100 suspension is still computed by the wallet/COD service. The notification is a message about that fact, not the suspension rule.

---

## APIs

| Method | Path | Auth |
|---|---|---|
| GET | `/v1/notifications` | Session |
| GET | `/v1/notifications/unread-count` | Session |
| POST | `/v1/notifications/:id/read` | Session |
| POST | `/v1/notifications/read-all` | Session |
| GET | `/v1/notification-preferences` | Session |
| PUT | `/v1/notification-preferences` | Session |
| GET | `/health/worker` | Public (counts only; no payloads, secrets, or tokens) |

Worker loop is process-internal. Do not expose a public process-delivery endpoint.

---

## Logging

Structured JSON via existing `AppLogger`. Worker events include:

- `delivery_id`, `notification_id`, `channel`, `attempt`, `result`

Do not log JWT, refresh tokens, OTP, provider secrets, or raw delivery bodies beyond title/type already stored.

---

## Provider integration deferred

Not in this phase:

- FCM / APNs production credentials
- Device token registry
- Redis unread counters
- Admin broadcast campaigns
- In-app chat (Master: not V1)

---

**End of NOTIFICATION ARCHITECTURE**
