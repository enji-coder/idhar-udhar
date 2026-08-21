# UNIFIED ENTITY RELATIONSHIPS

Single source of truth for IDHAR UDHAR. IDs are UUIDs unless noted. Names are never join keys.

```text
Organization / CompanyProfile
   └── AdminUser (RBAC)
          └── AuditLog

PaymentSettingsVersion  (effective_from, percentages, created_by)
Coupon / Promotion / Zone / ParcelCategory / ParcelSize
VehicleCategory  <──────────────────────────────────────────┐
                                                            │
Customer ── Wallet ── WalletTransaction                     │
   ├── CustomerAddress                                      │
   ├── Device / PushToken                                   │
   ├── Notification                                         │
   └── Order ───────────────────────────────────────────────┤
          ├── OrderStop (pickup, drop snapshots)            │
          ├── OrderParcel (category, size, weight, fragile, COD, instructions)
          ├── vehicle_category_id + VehicleSnapshot ────────┘
          ├── rider_id + RiderSnapshot (after assign)
          ├── OrderStatusEvent
          ├── FareQuote / OrderFareSnapshot
          ├── OrderFinanceSnapshot  ← copies PaymentSettingsVersion rates + computed amounts
          ├── Payment
          ├── Invoice
          ├── ProofOfDelivery
          ├── Rating (customer↔rider)
          └── CouponRedemption

Rider ── Wallet ── WalletTransaction
   ├── RiderDriver (if distinct)
   ├── RiderVehicle ── vehicle_category_id
   ├── RiderDocument (files in object storage)
   ├── RiderBankAccount / RiderUpi
   ├── RiderAvailability (online)
   ├── RiderLocation (recent point; history optional)
   ├── VerificationCase
   ├── OrderOffer (pending accept)
   ├── Payout
   └── AnnouncementReceipt

Fleet Vehicle (Admin) may equal RiderVehicle or be company-owned later.

SupportTicket ── messages
NotificationCampaign ── fan-out to Notification
PurchaseInvoice (ops expense; not customer invoice)
DailyReportAggregate (materialized)
```

## Shared masters (all three apps)

| Master | Customer | Rider | Admin |
|---|---|---|---|
| VehicleCategory | select by id | select by id | CRUD |
| Order | create/read own | assigned offers/jobs | ops |
| Customer | self | masked on job | full (RBAC) |
| Rider | public snapshot on job | self | full |
| Wallet | own | own | finance view |
| Invoice | own | no | finance |
| Notification | own inbox | own inbox | campaigns + own |
| Announcement | if audience includes | if audience includes | CRUD |
| Coupon | redeem at book | no | CRUD |
| Zone | implicit serviceability | home zone | CRUD |

## Snapshot rule

Historical Order, Invoice, and Finance rows **copy** names, addresses, vehicle labels, percentages, and money amounts at freeze time. They keep FKs for navigation but **never recompute money from current Settings**.
