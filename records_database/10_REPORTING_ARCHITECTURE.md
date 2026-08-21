# REPORTING ARCHITECTURE

Admin must keep: Daily Order Breakup, Weekly/Monthly/Yearly revenue, totals, completed/cancelled/failed, rider earnings, commission, opex, profit, customer/rider/vehicle-category/payment/wallet stats, performance colors (green / light orange / red).

Current: `dashboardMetrics.js` folds **all in-memory orders** per period. That cannot serve millions of rows in the browser.

## Day 1

1. **Transactional truth:** `order`, `order_finance_snapshot`, `payment`, `wallet_transaction`.  
2. **Nightly + near-real-time worker** upserts `daily_order_stats` (date × zone × vehicle_category × maybe city): counts and **summed snapshot money**.  
3. Admin overview API reads aggregates + last-N-minutes increment from a small “hot” Redis or `orders where created_at > last_rollup`.  
4. Exports (`exportEngine`) run **server-side** CSV/XLSX jobs, signed download URL — not client-side scan.

## Periods

Map existing `REVENUE_PERIODS` today/weekly/monthly/yearly to date windows (`dashboardMetrics.periodWindow` logic) **on the server**.

Revenue definition (keep Admin): exclude Cancelled and Failed from GMV; still count them in cancel/fail rates.

## Performance indicators

Keep `BUSINESS_PERFORMANCE_THRESHOLDS` as **config table** (admin-editable later): change %, completion %, cancel %, bar ratio. Failed/cancel → red as today.

## What not to do

- Load entire order list into Reports page.  
- Recalculate historical ₹ with current 85/15/50.  
- Use mock `kpis` constants as production numbers.

## Later

Materialized views refresh 5–15 min; read replica for reports; partition facts by month.
