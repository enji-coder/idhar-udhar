# ADMIN WEBAPP — DATABASE DISCOVERY REPORT

**Scope:** `IDHAR_UDHAR_ADMIN/` (React + Vite).  
**Method:** Code inspection only. No Admin UI, Netlify, or dummy data changed.  
**Nature today:** Browser-side “backend”: `localStorage` entity stores (`createEntityStore`) + mock JS datasets. Real HTTP exists for **admin login/session** and **vehicle-categories** Netlify functions. Dashboard can refresh via in-page live snapshot (`dashboardLive.js`), not a server.

**Superseded for current-state (2026-08-21):** `FINAL_MASTER_ANALYSIS.md`. Keep this file as historical discovery. Order drawer now shows payment responsibility, paid amounts, and UNPAID / PARTIALLY_PAID / PAID. New Admin orders stay UNPAID (online is not faked Paid).

---

## 1. Application Overview

**Routes (`App.jsx`):** Dashboard, Live Operations, Orders, Tracking, Riders (+ detail), Customers (+ detail), Verification, Payments, Earnings, Payouts, Coupons, Promotions, Notifications, Support, Reports, Settings, Profile, Vehicles, Vehicle Categories, Wallet, Zones, Invoices, Purchase Invoices, Announcements. Redirects: `/upi-settings` → Payments, `/promo-codes` → Coupons.

**Auth:** `AuthContext` + Netlify `admin-login` / `admin-session` / `admin-logout`. Seed accounts in `adminAccounts.js` (Super Admin, Operations, Finance, Support, Manager, Sub Admin). Sub-admin has **module allow-list** and `financeAccess` / `payoutApprove` flags. **Do not copy passwords from source into this report.**

**RBAC:** `config/permissions.js` — roles + path + action matrix (`can`, `canAccessPath`, `filterNav`). Settings path Super Admin only.

**Persistence:** `services/stores.js` keys such as `orders_v3`, `riders_v3`, `customers_v2`, `vehicles_v1`, `wallet_v2`, `invoices_v1`, etc. Vehicle categories also PUT to `/.netlify/functions/vehicle-categories` (Netlify Blobs or in-memory). Payment settings in `localStorage` key `iu_admin_settings`.

---

## 2. Sidebar / feature inventory (must be supported)

### Overview
- **Dashboard:** KPIs, revenue period Today/Weekly/Monthly/Yearly, weekly-style bars, business performance High/Medium/Low (green / light orange / red), cancel/failed as red, live-ish refresh hook.

### Operations
- Live Operations  
- Orders (search/filter/create/edit/assign/cancel/refund/invoice/timeline/POD note)  
- Riders + Rider detail (docs, earnings, performance)  
- Customers + Customer detail (orders, addresses, activity)  
- Vehicles (fleet CRUD-ish dummy)  
- Vehicle Categories (add/edit/activate/deactivate/delete-if-unused, availability flag synced to apps)  
- Zones  
- Tracking  
- Verification (KYC: identity, licence, RC, insurance, photo)

### Finance
- Payments (collections, refunds, settlements, methods UPI/Cash/Card/Net Banking/Wallet)  
- Wallet (customer + rider txns)  
- Invoices (customer GST-style PDF preview/download, company logo)  
- Purchase Invoices (vendor/vehicle/expense)  
- Earnings (commission, incentive, tips)  
- Payouts (Pending/Approved/Paid/Rejected)

### Management
- Reports (export; daily breakup; finance joins)  
- Notifications (campaigns: target Customers/Riders, priority, draft/sent)  
- Company Announcements (audience Riders/Customers/All/Operations)  
- Coupons  
- Promotions / referrals  
- Support tickets

### System
- Settings (payment split %, enabled payment modes, company)  
- Profile  

**Do not drop any of these** in the production architecture.

---

## 3. Admin entities (from mock + stores)

| Entity | Store / source | Key fields |
|---|---|---|
| AdminUser | adminUsers / adminAccounts | id, name, email, role, status, financeAccess, payoutApprove, modules[] |
| Customer | customerStore | id C-*, name, phone, email, orders, spent, status (New/Active/Repeat/Inactive), joined, area |
| Rider | riderStore | id R-*, name, phone, vehicle (name), vehicleNumber, status (Busy/Active/Offline/Pending), rating, deliveries, earnings, verification, zone, onTime, cancelRate, score, monthDeliveries |
| Vehicle | vehicleStore | id VH-*, number, rcNumber, type/category, twoWheelerType, brand, model, variant, color, riderId, status, capacity, registered, lastService, insurance, rcExpiry, insuranceExpiry |
| VehicleCategory | vehicleCategoryStore + Netlify | id VC-*, name, status Active/Inactive, available, createdAt, updatedAt |
| Zone | zoneStore | id, name, area, activeRiders, orders, status |
| Order | orderStore | See §4 |
| Payment / Transaction | paymentStore | TXN-*, orderId, customer, amount, method, status, gatewayStatus, date |
| WalletTransaction | walletStore | WLT-*, user, userType Customer\|Rider, type Credit/Debit/Refund/Adjustment, amount, balance, status, method, description |
| Invoice | invoiceStore | INV-*, orderId, tax, discount, total, paymentStatus, paymentMethod |
| PurchaseInvoice | purchaseInvoiceStore | PINV-*, vendor, itemType Vehicle/Maintenance/Insurance/Parts |
| Payout | payoutStore | PO-*, riderId, amount, status, method, period |
| Coupon | couponStore | code, discountType Percent\|Flat, limits, service, customerType, dates |
| Promotion | promotionStore | audience Riders\|Customers, type Campaign\|Referral |
| Ticket | ticketStore | support tickets, assignee, replies |
| Announcement | announcementStore | audience, status Published\|Draft |
| NotificationCampaign | campaignStore | target, priority, status Sent\|Draft |
| AuditLog | auditStore | adminId, action, module, recordId, previousValue, newValue, timestamp |
| Verification row | mock `verifications` | identity/licence/rc/insurance/photo statuses |
| Company | config/company.js | legal name, GSTIN, CIN, PAN, bank, address (invoice header) |
| PaymentSettings | localStorage | riderSharePercent 85, companyCommissionPercent 15, operationalCostPercent 50 |
| Earnings daily row | mock `earnings` | commission, incentive, tips |

---

## 4. Order record (Admin)

Typical fields: `id`, `customer`, `customerId`, `rider`, `riderId`, `pickup`, `destination`, `status`, `amount`, `payment`, `date`, `eta`, `distance`, `vehicle`, `vehicleNumber`, `time`, `customerPhone`, `customerEmail`, `pickupAddress`, `destinationAddress`, `packageType`, `weight`, `quantity`, `instructions`, `paymentStatus`, optional `deliveredAt`, `proofNote`, `customerRating`, `riderRating`, `discount`, `cancelledBy`, finance snapshot fields (`financeSnapshot` / `riderCommission` / `companyCommission` / `operationalExpense` / `netCompanyEarnings`).

**ORDER_STATUSES:** Pending, Assigned, Rider Arriving, Out for Delivery, Picked Up, In Transit, Delivered, Cancelled, Failed. Maps also mention Searching, Accepted, Returned.

**Delivery report statuses:** Delivery Pending, In-Transit, Out for Delivery, Delivered, Failed / Returned.

**Cancel reasons:** Customer Request, Rider Issue, Operational Issue, Payment Issue, Other. **Cancelled by:** Customer, Rider, Admin.

**Timeline steps:** Order Created → Rider Assigned → Rider Arrived → Package Picked Up → In Transit → Delivered.

**Actions (`orderRules.js`):** view, track, edit, reassign, assign, invoice, cancel, refund (delivered), proof (delivered).

---

## 5. Payment / commission (already in Admin code)

`services/commission.js` implements the required business rule:

- rider_amount = total × riderSharePercent/100 (default 85)  
- company_commission = remainder (default 15%)  
- operational_cost = company_commission × operationalCostPercent/100 (default 50% of commission)  
- actual_profit = company_commission − operational_cost  

`attachFinanceSnapshot` / `calculateOrderFinance` **prefer stored snapshot** so later Settings changes should not rewrite old orders **if snapshot exists**. Live Settings live in `iu_admin_settings` without version history or `updatedBy` in the current UI.

Cancelled/Failed: distribution of **0** rider/company from the ride, customer payment still shown. Unassigned rider: 100% treated as company commission.

Invoice builder: delivery charge = order.amount, packaging heuristic, tax default **5%**, discount, company GST header. **Invoice tax 5% vs commission opex 50% are different concepts.**

---

## 6. Dashboard / reporting (code)

`dashboardMetrics.js`: periods today/weekly/monthly/yearly; revenue from `calculateOrderFinance.totalAmount` excluding Cancelled/Failed; completion/cancel %; bar colors via `performance.js` thresholds (high change ≥8%, completion ≥90%, cancel ≤3% for green, etc.). **Computes over in-memory order arrays** — will not scale.

`reportJoin.js` exists for report joins. Export engine present.

Daily Order Breakup and finance KPIs are Admin UI requirements.

---

## 7. Vehicle category master (only live cross-app API)

- Admin CRUD local + `PUT /.netlify/functions/vehicle-categories`  
- GET public (active only) consumed by Customer and Rider  
- IDs `VC-1001`… but **usage rename still patches orders/riders/vehicles by category name**  
- `available` derived from whether a live vehicle of that **name** exists  
- Delete blocked if usage.total > 0; deactivate instead  

Fallback lists in Flutter still name-match (`Bike` vs customer `Three Wheeler`/`Auto` mismatch).

---

## 8. Dummy vs production gaps

- All operational data is mock + localStorage.  
- Dashboard KPI numbers in `mockData.kpis` can diverge from computed metrics.  
- Name-based joins (`order.rider === rider.name`) throughout wallet/earnings.  
- Vehicle types include Scooter, Van, Auto, Bike, Tempo — not identical to VC master.  
- Admin login secrets in repo (report location only).  
- Audit log exists but previous/new values are strings.  
- No geolocation points; tracking is UI over dummy orders.  
- 10-second dashboard refresh is a **product requirement**; current `dashboardLive` is in-browser publish, not polling a server.

---

## 9. Recommended production entities (Admin-driven)

All of §3 plus: PaymentSettingsVersion, OrderFinanceSnapshot, OrderStatusHistory, ProofOfDelivery, CouponRedemption, SupportTicketMessage, ReportAggregateDaily, NotificationInbox (per user), FileObject metadata.

**Do not implement in this step.**
