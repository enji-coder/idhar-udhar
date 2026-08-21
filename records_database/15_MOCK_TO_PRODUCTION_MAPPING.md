# MOCK → PRODUCTION MAPPING

Do not rename UI models in apps until a later integration step. This is the mapping only.

## Customer (`lib/customer`)

| Current | Production |
|---|---|
| MockUser | customer |
| PersistedSession / SessionState | session_token + GET /customers/me |
| MockLocation (saved) | customer_address |
| AddressLabel | address.label enum |
| MockVehicle | vehicle_category + fare_quote (not a separate vehicle row per listing) |
| VehicleType / ServiceFamily | vehicle_category attributes / service_family on order |
| VehicleCategory (shared) | vehicle_category (**keep ID**) |
| MockParcelCategory | parcel_category |
| MockParcelSize | parcel_size |
| BookingDraft | client cache; server fare_quote + POST /orders |
| FareBreakdown | fare_quote + order_fare_snapshot |
| MockOrder | order + stops + parcel + snapshots |
| OrderStatus | canonical status enum |
| MockRider | rider snapshot on order |
| SessionState.walletBalance | wallet.available_balance |
| MockWalletTxn | wallet_transaction |
| WalletPaymentOption | payment method catalog |
| invoiceSent / invoiceEmail | invoice + email job |
| Decorative rating stars | rating |
| Invite ₹200 banner | promotion / referral |
| Hardcoded notification badge | notification unread-count |

## Rider (`lib/rider`)

| Current | Production |
|---|---|
| RiderProfile | rider |
| RiderDriverDetails | rider_driver (or rider columns) |
| VehicleInfo | vehicle (FK vehicle_category_id) |
| RiderVehicleType | drop; use category id |
| RiderDocument | rider_document + file_object |
| RiderBankDetails | rider_bank_account + rider_upi |
| DummyRiderData.otp | otp_challenge |
| RiderPrefs flags | session + onboarding_state |
| riderOnlineProvider | rider_availability / presence Redis |
| RiderOrder | order + order_offer |
| DeliveryLifecycleStatus | canonical status subset |
| RecentActivityItem | order list + status |
| RiderEarnings / RecentEarningItem | aggregates from order_finance_snapshot + incentives |
| riderWalletBalanceProvider | wallet |
| RiderAnnouncement | announcement + notification |
| VerificationStep | verification_case |

## Admin (`IDHAR_UDHAR_ADMIN`)

| Current | Production |
|---|---|
| localStorage entityStore | PostgreSQL via API |
| adminAccounts | admin_user (passwords hashed server-side) |
| customers[] | customer |
| riders[] | rider |
| vehicles[] | vehicle |
| vehicle_categories_v1 + Netlify blobs | vehicle_category |
| orders_v3 | order + snapshots |
| transactions | payment |
| walletTransactions | wallet_transaction |
| invoices / buildInvoice | invoice |
| purchaseInvoices | purchase_invoice |
| payouts | payout |
| coupons / promotions | coupon / promotion |
| tickets | support_ticket |
| announcements / campaigns | announcement / notification_campaign |
| zones | zone |
| verifications | rider_document statuses |
| iu_admin_settings | payment_settings_version |
| financeSnapshot on order | order_finance_snapshot |
| auditStore | audit_log |
| dashboardMetrics over arrays | daily_order_stats API |
| company.js | company_profile |
| logoDataUrl | public file |

## Shared HTTP today

`GET vehicle-categories` → remains conceptually `GET /v1/vehicle-categories` (stable IDs, stop name matching in Flutter `categoryNameOf`).
