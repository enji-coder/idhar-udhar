# NOTIFICATION ARCHITECTURE

## Current state

- **Customer:** dashboard badge hardcoded `3`; Profile “Notifications” `onTap` empty; no model.  
- **Rider:** company announcements dummy list; OS notification permission; overlay for offers.  
- **Admin:** `notificationCampaigns` (broadcast drafts) + `announcements` (ops notices). Not a per-user inbox.

## Production

Three products:

1. **Transactional inbox** (per customer/rider/admin user)  
2. **Push** (FCM)  
3. **Campaigns / announcements** (Admin) that **fan-out** into (1)+(2)

### notification row
- id, recipient_type, recipient_id  
- type (enum): otp_not_here (OTP is SMS), order_searching_timeout, rider_assigned, rider_arriving, picked_up, in_transit, delivered, cancelled, offer_incoming, payout, kyc, wallet, announcement, promo  
- title, body  
- data jsonb: order_id, rider_id, customer_id, deep_link (`/orders/:id`, `/rider/orders/active`, …)  
- read_at, created_at, expires_at optional  
- campaign_id optional  

### Scale
- List: `WHERE recipient = me ORDER BY created_at DESC, id DESC LIMIT n` + cursor.  
- Unread: Redis counter `unread:{type}:{id}` incremented by worker, decremented on read; fallback `COUNT(*) WHERE read_at IS NULL` (bounded).  
- **Never** `SELECT * FROM notifications` for a user without limit.  
- Partition by month when large.  
- Campaign to 100k users: enqueue chunk jobs, not one HTTP from Admin browser.

### Delivery
- Worker writes DB row then push.  
- Client dedupes by id.  
- Admin campaign status: draft → sending → sent (counts).

### Deep links
Map types to Customer/Rider/Admin routes already in the apps (order details, incoming, wallet, verification).
