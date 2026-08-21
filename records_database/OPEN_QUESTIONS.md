# OPEN QUESTIONS

Business questions answered in the 2026-08-21 alignment prompt are **FINALIZED**. They are not repeated as open.

Only items that still cannot be determined from current code + `18_FINAL_BUSINESS_DECISIONS.md` remain here.

---

## CRITICAL

**No critical open questions identified.**

Commission base, resend splits, COD, cancellation configurability, company office, payment splitting, and V1 online+cash are finalized in `18`.

---

## NON-CRITICAL

These do not block the freeze contract. They are product/ops details.

| # | Topic | Why it is still open |
|---|---|---|
| 1 | OTP length and SMS provider | Customer demo accepts any 4-digit code. Rider registration OTP is dummy `123456`. Login on Rider still skips OTP. |
| 2 | Extra multi-stop fees | Max 3 drops locked. No extra stop fee in the fare engine. Future extra fee not decided. |
| 3 | Owner vs hired driver | Rider app still collects profile and driver details for one dummy person. |
| 4 | Referral / promo program | Dummy wallet credits, invite banner, Admin coupons are not one program. |
| 5 | Wallet KYC / min top-up | Recharge exists in demo. KYC and min/max top-up not chosen. |
| 6 | Rating both ways | Dummy stars only. |
| 7 | Pickup/drop contact names | Customer does not collect stop contacts. |
| 8 | No-rider-found TTL / dispatch | Searching is a 3s demo timer. Rider offer timer is 27s dummy. |
| 9 | Statutory invoice SAC / e-invoice | Fare GST remains ₹0. Letterhead GSTIN is display-only. |
| 10 | Cross-app live order sync | Customer, Rider, and Admin still use **separate mock stores**. Shared IDs/status/engines are ready; a real backend is **IMPLEMENTATION PENDING BACKEND**. |

---

## FINALIZED (do not re-open)

| Topic | Final rule |
|---|---|
| 85/15 base | Confirmed **Trip Fare**, not discounted customer payable |
| Historical snapshots | Immutable; Admin rate changes do not rewrite old trips |
| Canonical trip ID | `IU-AMD-` + 10-digit sequence (display). UUID planned for Postgres PK |
| Canonical status | One machine in `order_lifecycle.dart`; UIs map labels |
| COD | Supported. COD Due separate. Wallet never negative. Auto-settle from eligible earnings. Suspend at COD Due ≥ ₹100 |
| Wallet recharge | Clears COD Due first |
| Resend Case A (trip ended) | Base fare + ₹10/km; 85/15 on both |
| Resend Case B (trip active) | ₹10/km customer; ₹8/km rider; ₹2/km company |
| Payment methods V1 | Online and Cash. WHO PAYS and HOW THEY PAY are separate. Split payment is FINAL |
| Company office | Admin-configurable address + lat/lng |
| Cancellation | Admin stage-wise; customer and rider separate; default fee ₹0; rider%+company%=100; not auto 85/15 |
| GST | ₹0 on fare |
