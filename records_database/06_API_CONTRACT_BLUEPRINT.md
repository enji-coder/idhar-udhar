# API CONTRACT BLUEPRINT

**Do not implement.** HTTPS JSON, version prefix `/v1`. Auth: `Authorization: Bearer <access>` + refresh cookie/body. Actors: customer | rider | admin. Idempotency-Key on payments, order create, offer accept.

Errors: `{ "error": { "code": "ORDER_NOT_CANCELABLE", "message": "..." } }` with 4xx/5xx. Never leak internals.

Pagination: cursor `?cursor=&limit=` (default 20, max 100). List endpoints never return unbounded arrays.

---

## Auth
- `POST /v1/auth/otp/request` { phone, actor_type }  
- `POST /v1/auth/otp/verify` { phone, actor_type, code } → tokens + user  
- `POST /v1/auth/token/refresh`  
- `POST /v1/auth/logout`  
Admin email/password remains separate: `POST /v1/admin/auth/login` (server-side only).

## Customer
- `GET/PATCH /v1/customers/me`  
- `GET/POST /v1/customers/me/addresses`  
- `PATCH/DELETE /v1/customers/me/addresses/:id`  
- `GET /v1/customers/me/orders?status=&cursor=`  
- `GET /v1/customers/me/wallet`  
- `GET /v1/customers/me/wallet/transactions?cursor=`  
- `POST /v1/customers/me/wallet/top-up` (idempotent payment intent)

## Rider
- `GET/PATCH /v1/riders/me`  
- `PUT /v1/riders/me/vehicle`  
- `PUT /v1/riders/me/bank` / `upi`  
- `POST /v1/riders/me/documents` (presigned upload then confirm)  
- `POST /v1/riders/me/availability` { online }  
- `POST /v1/riders/me/location` (throttled; or websocket)  
- `GET /v1/riders/me/offers`  
- `POST /v1/orders/:id/offers/:offerId/accept` **idempotent / row lock**  
- `POST /v1/orders/:id/offers/:offerId/reject`  
- `GET /v1/riders/me/orders?cursor=`  
- `GET /v1/riders/me/earnings?from=&to=`  
- `GET /v1/riders/me/wallet`

## Vehicle categories (shared)
- `GET /v1/vehicle-categories` (active+available for apps)  
- `GET /v1/admin/vehicle-categories` (all)  
- `POST /v1/admin/vehicle-categories`  
- `PATCH /v1/admin/vehicle-categories/:id`  
- `POST /v1/admin/vehicle-categories/:id/deactivate`  
- Delete only if unused: `DELETE /v1/admin/vehicle-categories/:id`

## Catalog
- `GET /v1/parcel-categories`  
- `GET /v1/parcel-sizes`  
- `GET /v1/zones`

## Orders
- `POST /v1/fare/quotes` { pickup, drop, vehicle_category_id, parcel }  
- `POST /v1/orders` { quote_id, addresses, parcel, payment_method }  
- `GET /v1/orders/:id` (authorized party)  
- `POST /v1/orders/:id/cancel`  
- `POST /v1/orders/:id/status` { to_status } rider/admin allowed transitions only  
- Admin: `GET /v1/admin/orders?status=&from=&to=&q=&cursor=`  
- `POST /v1/admin/orders/:id/assign` { rider_id }  
- `POST /v1/admin/orders/:id/reassign`

## Payments / invoices
- `GET /v1/orders/:id/payment`  
- Provider webhook `POST /v1/webhooks/payments/:provider` (signature verify)  
- `POST /v1/admin/orders/:id/refund`  
- `GET /v1/orders/:id/invoice`  
- `GET /v1/orders/:id/invoice.pdf` (signed URL)

## Notifications
- `GET /v1/notifications?cursor=`  
- `POST /v1/notifications/:id/read`  
- `GET /v1/notifications/unread-count`  
- Admin campaigns: `POST /v1/admin/notification-campaigns`

## Announcements
- `GET /v1/announcements`  
- Admin CRUD `/v1/admin/announcements`

## Reports (admin finance/manager)
- `GET /v1/admin/reports/overview?period=today|weekly|monthly|yearly`  
- `GET /v1/admin/reports/daily-breakup?date=`  
- `GET /v1/admin/reports/finance?from=&to=`  
Always from aggregates + filtered queries, never dump all orders.

## Tracking
- REST `GET /v1/orders/:id/tracking` (snapshot)  
- WebSocket `/v1/realtime` subscribe `order:{id}`, `rider:{id}`

## Coupons / support / vehicles / payouts
Standard REST under `/v1/admin/...` matching existing Admin screens. Customer `POST /v1/orders/:id/coupon`.

---

## Authorization
Backend enforces: customer only own rows; rider only assigned/offered; admin via RBAC (`permissions.js` roles mapped to claims). No app writes Postgres directly.

## Idempotency
Accept offer, create order, wallet top-up, webhook processing: unique keys, 409 on conflict with same body OK.
