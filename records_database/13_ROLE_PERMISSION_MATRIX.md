# ROLE / PERMISSION MATRIX

Derived from Admin `config/permissions.js` plus Customer and Rider apps. Enforcement belongs on the **backend**.

**Current-app matrix (2026-08-21):** see `FINAL_MASTER_ANALYSIS.md` section 10. This file remains the **target** backend matrix.

## Actors

| Role | Source |
|---|---|
| Customer | Customer app |
| Rider | Rider app |
| Super Admin | Admin |
| Sub Admin | Admin (modules[], financeAccess, payoutApprove) |
| Operations | Admin |
| Finance | Admin |
| Support | Admin |
| Manager | Admin |

## ENTITY \| CUSTOMER \| RIDER \| ADMIN \| BACKEND \| DATABASE

| Entity | Customer | Rider | Admin | Backend | Database |
|---|---|---|---|---|---|
| Customer | read/update self | masked on assigned order | view/edit/activate per RBAC | authority | persist |
| CustomerAddress | CRUD own | pickup/drop snapshot only | view on order | validate | persist |
| Rider | public snapshot on job | CRUD self (limited) | full KYC/ops | authority | persist |
| RiderDocument | none | upload own | approve/reject | virus+status | metadata; files S3 |
| RiderBank/UPI | none | update own (masked display) | finance view | encrypt | persist |
| VehicleCategory | list/select | list/select | CRUD | cache+validate | persist |
| Vehicle | none | own vehicle | fleet CRUD | | persist |
| Order | create/read own; cancel if allowed | offered/assigned status updates | ops assign/cancel/refund | **state machine** | persist |
| OrderOffer | none | accept/reject | monitor | lock | persist |
| FareQuote | request | estimated earnings view | — | compute | persist short TTL |
| Payment | initiate own (customer/receiver plan) | cash confirm later | refund/export; view transactions | webhooks | persist |
| Wallet | own | own | finance view | atomic | persist |
| Invoice | read own | none | issue/download | generate | persist + PDF |
| FinanceSnapshot | none | none | read reports | freeze write | immutable |
| PaymentSettings | none | none | Super Admin Settings | version insert | persist |
| Notification | own inbox | own inbox | campaigns + own | fan-out | persist |
| Announcement | if targeted | if targeted | CRUD | | persist |
| Coupon | redeem | none | CRUD (Manager+) | | persist |
| Zone | implicit | home zone | CRUD | | persist |
| SupportTicket | future | future | Support | | persist |
| Payout | none | read own | Finance approve | | persist |
| AuditLog | none | none | Super Admin read | append | append-only |
| Report aggregates | none | none | finance/manager | workers | persist |
| AdminUser | none | none | Super Admin settings | | persist |

## Admin action map (keep)

Orders: view, track, edit, assign, cancel; refund = Super Admin + Finance (Sub Admin refund false).  
Riders: approve/reject/suspend = Super Admin + Operations.  
Customers: activate/deactivate = Super Admin + Support.  
Coupons delete = Super Admin.  
Settings path = Super Admin only.  
Sub Admin: no settings; finance routes gated by `financeAccess`; payout approve gated by flag.

Customers and Riders **never** get Admin modules.
