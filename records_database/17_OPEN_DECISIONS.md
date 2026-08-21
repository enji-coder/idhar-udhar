# OPEN DECISIONS

**Historical list** from the first architecture pass.  
**Current remaining questions (2026-08-21):** `OPEN_QUESTIONS.md` (no critical items). Commission base, COD, cancellation, resend splits, company office, payment splitting, and V1 online+cash are **FINALIZED** in `18`.

Only items that cannot be closed from current code plus the stated 85/15/50 finance rule. Grouped by when they block work.

---

## Critical before database implementation

1. **Canonical order ID format** — **Target locked** (`18` A: `IU-{CITY}-{10-digit}`). Customer *new* bookings now use that helper. Rider dummy and Admin short pad still differ. Uniqueness in production is still a database sequence, not mock generators.  
2. **When finance snapshot freezes** — on confirm, on rider accept, or on delivered? (Recommend: quote at confirm; **P&L freeze on delivered**, cancel/fail policy below.)  
3. **Cancelled money** — V1: no cancellation fee; rider/company split is zeroed. Failed delivery is a **separate** workflow (see 13).
4. **COD cash** — collected at pickup or drop? Does rider keep cash_in_hand netted from payouts? Customer COD toggle is **not** stored on MockOrder.  
5. **Online payment timing** — Customer confirm has no payment step; Admin has Paid/Pending. Authorize at book vs capture at delivery?  
6. **Ride amount vs invoice total** — Commission is on `order.amount`. **NO GST on fare.** Confirm extras (packaging) vs 85/15 base.  
7. **Operational cost meaning** — 50% of company commission is an allocation, not a vendor invoice. Confirm it is not double-counted with `purchase_invoices`.  
8. **Owner vs driver** — Rider app collects both profile and driver details (same dummy person). Fleet owner with hired driver: one rider login or two identities?  
9. **Service geography** — Ahmedabad-centric Admin; Customer dummy includes Surat. First launch city / multi-city keys?

---

## Important before backend implementation

10. **OTP** — Customer 4-digit any code vs Rider 6-digit `123456`. Length, provider, resend, attempt lock.  
11. **Email mandatory** — optional on profile, required before Customer tracking.  
12. **Cancel after assigned** — Customer `canCancel` includes assigned; after accepted, no. **Fee remains ₹0 in V1.**  
13. **Failed delivery** — ✅ operational flow locked (receiver unavailable → company office → ₹8/km rider + optional ₹10/km customer resend). **Still open:** internal split of the ₹10/km resend charge; live company-office pin.  
14. **No rider found** — retry, expand radius, admin assign, auto-cancel TTL?  
15. **Dispatch** — broadcast vs sequential offers; 27s is dummy. Max concurrent offers.  
16. **Live GPS interval, retention, privacy** — customer only during active job?  
17. **Call masking** vs raw numbers (Customer has rider phone; Rider masks customer).  
18. **Chat** — Message buttons are empty; in-scope for v1?  
19. **GST** — **NO GST on V1 fare.** SAC / GSTIN / e-invoice still open for statutory invoices.  
20. **Distance fare** — Admin per-km field is the source of truth. Multi-location uses total route distance across ordered stops. **Max delivery locations = 3.** Extra multi-stop fees are still open (none invented).  
21. **Fragile / 36 cm two-wheeler rule** — enforce vs size catalog mismatch (Medium 60 cm).  
22. **Scooty / Scooter / Van** — Customer scooty, Admin scooter/van, VC master has neither scooty nor van.  
23. **Scheduled booking** — field exists, no UI. Keep in schema nullable?  
24. **Referral ₹200 vs promo credit ₹50 vs Admin Refer & Earn ₹150** — one program.  
25. **Wallet KYC / min top-up / auto-debit on book.**  
26. **Rating** — 1–5 both ways? Comment? Shown on rider profile?  
27. **Invoice email vs in-app PDF.**  
28. **Pickup/drop contact names** — not collected in Customer; Admin instructions sometimes include names.  
29. **Sub-admin password policy** — move secrets out of repo before any real auth.  
30. **₹10/km resend distribution** — rider vs company vs neither. Do not invent.  
31. **Company office master** — live pin/address. Placeholder from `company.js` is not confirmed.

---

## Can be decided later

30. Push vendor (FCM vs other).  
31. WS vs Ably vs Pusher.  
32. Exact worker (Redis streams vs SQS vs Cloud Tasks).  
33. Partitioning / read replicas timing.  
34. Warehouse (BigQuery) for year-2 analytics.  
35. 2FA for Admin.  
36. Multi-stop / round-trip (not in apps).  
37. Customer parcel photos.  
38. Whether booking draft persists across app kill.  
39. Performance threshold numbers (8%/90%/3%) as Admin-editable config.  
40. Document retention years.

---

## Code vs requirement conflicts (do not silently “fix” apps)

| Topic | Code | Requirement / this architecture |
|---|---|---|
| Commission | Live settings can recompute orders **without** snapshot | Historical freeze mandatory |
| Vehicle join | Name matching | Stable IDs |
| Order statuses | Three vocabularies | One canonical machine |
| Customer payment step | Missing | Need a method before money moves |
| Dashboard | In-memory full scan | Aggregates |
| Secrets | Seed files / docs | Server env only |

Do not change UI in this run. Resolve these in implementation planning after approval.
