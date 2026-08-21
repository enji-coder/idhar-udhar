# DATA FLOW — CUSTOMER ↔ RIDER ↔ ADMIN

## Unified order status (one machine)

Map existing labels; **store the canonical value** in Postgres. Apps may display local copy.

| Canonical | Customer today | Rider today | Admin today |
|---|---|---|---|
| `created` | (confirm) | — | Pending |
| `searching` | searching | — | Searching / Pending |
| `offered` | — | incoming timer | Pending |
| `assigned` | assigned | accepted (start) | Assigned / Accepted |
| `en_route_pickup` | accepted / arriving | goingToPickup | Rider Arriving / Out for Delivery |
| `arrived_pickup` | arriving | arrivedAtPickup | Rider Arrived (timeline) |
| `picked_up` | pickup | packagePickedUp | Picked Up |
| `in_transit` | inTransit | goingToDrop | In Transit |
| `near_drop` | nearDestination | — | (optional) |
| `delivered` | delivered | delivered / Completed | Delivered |
| `cancelled` | cancelled | Cancelled / Rejected by Client | Cancelled |
| `failed` | **missing** | **missing** | Failed / Returned |
| `offer_rejected` | stays searching | Rejected by Rider | still Pending |

**Who may transition:** backend table. Customer: cancel only `searching|offered` (today: searching|assigned). Rider: offer accept/reject + delivery steps. Admin: assign/reassign/cancel/fail per `orderRules`.

---

## Happy path

```text
Customer POST quote → POST order (payment intent if online)
        ↓
status searching
Admin sees order (ops list)
        ↓
Dispatch worker creates order_offer(s) to online riders (category match)
        ↓
Rider push + incoming UI (server expiry)
        ↓
Rider ACCEPT (SELECT FOR UPDATE order; one winner)
        ↓
status assigned; Customer WS + push; Admin live
        ↓
Rider steps → picked_up → in_transit → delivered
        ↓
Freeze fare already stored; write order_finance_snapshot (settings version)
Credit rider wallet or cash_in_hand; capture payment if needed
Generate invoice PDF + email
Enqueue daily_order_stats increment
Notify all parties
```

## Sync rules

- Apps **never** sync via each other’s localStorage/SharedPreferences.  
- Vehicle category: Admin write → API → apps read IDs.  
- Payment settings: Admin write **new version** → only **new** freezes use it.  
- Display names on old orders come from **snapshots**.

## Conflicts (see also consistency section in master)

Simultaneous accept: unique accepted offer + order.rider_id not null constraint.  
Wallet debit vs order create: saga or single transaction (hold funds then create).
