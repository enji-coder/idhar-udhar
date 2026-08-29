/**
 * DEVELOPMENT ONLY. Exercises the live Nest API + Docker Postgres marketplace
 * flow. Does not print OTP codes, passwords, or tokens.
 */
import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import pg from 'pg';

function loadEnv(path) {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq < 1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

const root = resolve(import.meta.dirname, '..');
const repo = resolve(root, '..');
loadEnv(resolve(root, '.env'));
loadEnv(resolve(repo, 'records_database', '.env'));
loadEnv(resolve(repo, 'IDHAR_UDHAR_ADMIN', '.env'));

const API = 'http://127.0.0.1:3000';
const report = [];

function step(name, ok, extra = {}) {
  report.push({ name, ok, ...extra });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${extra.detail ? ` — ${extra.detail}` : ''}`);
}

async function http(method, path, { token, body, headers, origin } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      ...(body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(origin ? { origin } : {}),
      ...headers,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  let json = null;
  const text = await res.text();
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text.slice(0, 200) };
  }
  return { status: res.status, json, headers: res.headers };
}

function uniquePhone() {
  return `9${String(Date.now()).slice(-9)}`;
}

function assertNoSecrets(json) {
  const raw = JSON.stringify(json);
  return (
    !raw.includes('password_hash') &&
    !raw.includes('code_hash') &&
    !raw.includes('refresh_token_hash') &&
    !raw.includes('GOOGLE_MAPS_API_KEY')
  );
}

const client = new pg.Client({
  host: process.env.DATABASE_HOST,
  port: Number(process.env.DATABASE_PORT || 5432),
  database: process.env.DATABASE_NAME,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  ssl: false,
});

await client.connect();

try {
  const health = await http('GET', '/health');
  step('health', health.status === 200 && health.json?.database?.name === 'idhar_udhar', {
    detail: `${health.status} ${health.json?.database?.name || ''}`,
  });

  const cors = await fetch(`${API}/health/live`, {
    method: 'OPTIONS',
    headers: {
      origin: 'http://localhost:5173',
      'access-control-request-method': 'GET',
    },
  });
  step('cors_admin_5173', cors.headers.get('access-control-allow-origin') === 'http://localhost:5173', {
    detail: cors.headers.get('access-control-allow-origin') || 'none',
  });

  const flutterCors = await fetch(`${API}/health/live`, {
    method: 'OPTIONS',
    headers: {
      origin: 'http://localhost:7357',
      'access-control-request-method': 'GET',
    },
  });
  step(
    'cors_flutter_7357',
    flutterCors.headers.get('access-control-allow-origin') === 'http://localhost:7357',
    { detail: flutterCors.headers.get('access-control-allow-origin') || 'none' },
  );

  const catalog = await client.query(
    `
    SELECT c.city_id, c.city_code, v.vehicle_category_id, v.name
    FROM cities c
    CROSS JOIN vehicle_categories v
    WHERE c.city_code = 'AMD' AND c.active = TRUE AND v.active = TRUE
    ORDER BY v.name
    LIMIT 1
    `,
  );
  if (!catalog.rows[0]) {
    step('catalog', false, { detail: 'AMD city or vehicle category missing' });
    process.exitCode = 1;
    throw new Error('catalog missing');
  }
  const cityId = catalog.rows[0].city_id;
  const vehicleId = catalog.rows[0].vehicle_category_id;
  step('catalog', true, {
    detail: `${catalog.rows[0].city_code} / ${catalog.rows[0].name}`,
  });

  const customerPhone = uniquePhone();
  const otpReq = await http('POST', '/v1/auth/otp/request', {
    body: { phone: customerPhone, actor_type: 'CUSTOMER' },
  });
  step('customer_otp_request', otpReq.status === 200 && otpReq.json?.delivery === 'capture', {
    detail: `status ${otpReq.status} delivery ${otpReq.json?.delivery || 'none'}`,
  });
  const leaked = JSON.stringify(otpReq.json).match(/"code"\s*:/);
  step('otp_not_in_request_response', !leaked);

  const peek = await http(
    'GET',
    `/v1/auth/dev/otp-capture?phone=${customerPhone}`,
  );
  const customerCode = peek.json?.code;
  step('customer_otp_peek_loopback', peek.status === 200 && /^\d{4,8}$/.test(String(customerCode || '')), {
    detail: `status ${peek.status}`,
  });

  const customerVerify = await http('POST', '/v1/auth/otp/verify', {
    body: { phone: customerPhone, actor_type: 'CUSTOMER', code: customerCode },
  });
  const customerToken = customerVerify.json?.access_token;
  step('customer_otp_verify', customerVerify.status === 200 && Boolean(customerToken), {
    detail: `status ${customerVerify.status} role ${customerVerify.json?.role || customerVerify.json?.error?.code || ''}`,
  });

  const customerAdmin = await http('GET', '/v1/admin/orders', { token: customerToken });
  step('customer_cannot_admin', customerAdmin.status === 403, {
    detail: `status ${customerAdmin.status}`,
  });

  const created = await http('POST', '/v1/orders', {
    token: customerToken,
    headers: { 'Idempotency-Key': randomUUID() },
    body: {
      city_id: cityId,
      vehicle_category_id: vehicleId,
      stops: [
        {
          sequence: 0,
          stop_type: 'PICKUP',
          address_text: 'Pickup, Navrangpura',
          latitude: 23.0225,
          longitude: 72.5714,
        },
        {
          sequence: 1,
          stop_type: 'DROP',
          address_text: 'Drop 1, SG Highway',
          latitude: 23.04,
          longitude: 72.52,
        },
      ],
    },
  });
  const orderId = created.json?.order_id;
  const displayId = created.json?.display_id;
  step('customer_create_order', created.status === 201 && Boolean(orderId), {
    detail: `${created.status} ${displayId || created.json?.error?.code || ''}`,
  });

  const quote = await http('POST', `/v1/orders/${orderId}/quote`, {
    token: customerToken,
    body: {},
  });
  const fareQuoteId = quote.json?.fare_quote_id;
  const quoteSecretsOk = assertNoSecrets(quote.json);
  step(
    'customer_quote',
    quote.status === 201 && Boolean(fareQuoteId) && quote.json?.tax === '0.00' && quoteSecretsOk,
    {
      detail: `status ${quote.status} trip_fare ${quote.json?.trip_fare || 'n/a'} tax ${quote.json?.tax || 'n/a'}`,
    },
  );

  const confirm = await http('POST', `/v1/orders/${orderId}/confirm`, {
    token: customerToken,
    body: { fare_quote_id: fareQuoteId },
  });
  step('customer_confirm', confirm.status === 200 && confirm.json?.canonical_status === 'SEARCHING', {
    detail: `${confirm.status} ${confirm.json?.canonical_status || confirm.json?.error?.code || ''}`,
  });

  const dbOrder = await client.query(
    `
    SELECT o.canonical_status, o.display_id,
           (SELECT count(*)::int FROM order_stops s WHERE s.order_id = o.order_id) AS stops,
           (SELECT count(*)::int FROM fare_quotes q WHERE q.customer_profile_id = o.customer_profile_id) AS quotes,
           (SELECT count(*)::int FROM order_fare_snapshots f WHERE f.order_id = o.order_id) AS snapshots,
           (SELECT count(*)::int FROM order_status_events e WHERE e.order_id = o.order_id) AS events
    FROM orders o
    WHERE o.order_id = $1
    `,
    [orderId],
  );
  const row = dbOrder.rows[0];
  step(
    'postgres_order_authoritative',
    row?.canonical_status === 'SEARCHING' && row.stops >= 2 && row.snapshots >= 1 && row.events >= 1,
    {
      detail: `status ${row?.canonical_status} stops ${row?.stops} snapshots ${row?.snapshots} events ${row?.events}`,
    },
  );

  const email = (process.env.ADMIN_EMAIL || '').trim();
  const password = process.env.ADMIN_PASSWORD || '';
  const adminLogin = await http('POST', '/v1/admin/auth/login', {
    body: { email, password },
  });
  const adminToken = adminLogin.json?.access_token;
  step('admin_login', adminLogin.status === 200 && Boolean(adminToken), {
    detail: `status ${adminLogin.status}`,
  });

  const adminList = await http('GET', '/v1/admin/orders', { token: adminToken });
  const seen = (adminList.json?.orders || []).some((item) => item.order_id === orderId);
  step('admin_sees_order', adminList.status === 200 && seen, {
    detail: `status ${adminList.status} seen ${seen}`,
  });

  const riderRow = await client.query(
    `
    SELECT r.rider_profile_id, i.phone_normalized
    FROM rider_profiles r
    JOIN identities i ON i.identity_id = r.identity_id
    WHERE r.approval_status = 'APPROVED'
      AND r.online_status = 'ONLINE'
      AND r.cod_operational_status = 'CLEAR'
      AND r.deactivated_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM orders o
        WHERE o.rider_profile_id = r.rider_profile_id
          AND o.canonical_status NOT IN ('DELIVERED', 'CANCELLED', 'RESEND_COMPLETED')
      )
    ORDER BY r.created_at DESC
    LIMIT 1
    `,
  );
  if (!riderRow.rows[0]) {
    step('eligible_rider', false, {
      detail: 'No APPROVED+ONLINE rider without a live order',
    });
  } else {
    const riderProfileId = riderRow.rows[0].rider_profile_id;
    const riderPhone = riderRow.rows[0].phone_normalized;
    step('eligible_rider', true, { detail: `phone ****${riderPhone.slice(-4)}` });

    const offered = await http('POST', `/v1/admin/orders/${orderId}/offers`, {
      token: adminToken,
      body: { rider_profile_id: riderProfileId },
    });
    const offerId = offered.json?.order_offer_id;
    step('admin_offer', offered.status === 201 && Boolean(offerId), {
      detail: `${offered.status} ${offered.json?.status || offered.json?.error?.code || ''}`,
    });

    const riderOtp = await http('POST', '/v1/auth/otp/request', {
      body: { phone: riderPhone, actor_type: 'RIDER' },
    });
    const riderPeek = await http(
      'GET',
      `/v1/auth/dev/otp-capture?phone=${riderPhone}`,
    );
    const riderVerify = await http('POST', '/v1/auth/otp/verify', {
      body: {
        phone: riderPhone,
        actor_type: 'RIDER',
        code: riderPeek.json?.code,
      },
    });
    const riderToken = riderVerify.json?.access_token;
    step(
      'rider_otp_login',
      riderOtp.status === 200 && riderPeek.status === 200 && riderVerify.status === 200 && Boolean(riderToken),
      { detail: `verify ${riderVerify.status}` },
    );
    step(
      'session_tokens_isolated',
      Boolean(customerToken && riderToken && adminToken) &&
        customerToken !== riderToken &&
        riderToken !== adminToken &&
        customerToken !== adminToken,
    );

    const riderAdmin = await http('GET', '/v1/admin/orders', { token: riderToken });
    step('rider_cannot_admin', riderAdmin.status === 403, {
      detail: `status ${riderAdmin.status}`,
    });

    const offers = await http('GET', '/v1/rider/offers', { token: riderToken });
    const hasOffer = (offers.json?.offers || []).some(
      (item) => item.order_offer_id === offerId,
    );
    step('rider_sees_offer', offers.status === 200 && hasOffer, {
      detail: `status ${offers.status} has_offer ${hasOffer}`,
    });

    const accept = await http('POST', `/v1/rider/offers/${offerId}/accept`, {
      token: riderToken,
    });
    step('rider_accept', accept.status === 200 && accept.json?.order?.canonical_status === 'ASSIGNED', {
      detail: `${accept.status} ${accept.json?.order?.canonical_status || accept.json?.error?.code || ''}`,
    });

    const customerOrder = await http('GET', `/v1/orders/${orderId}`, {
      token: customerToken,
    });
    step(
      'customer_sees_assignment',
      customerOrder.status === 200 &&
        customerOrder.json?.canonical_status === 'ASSIGNED' &&
        customerOrder.json?.rider_profile_id === riderProfileId,
      { detail: customerOrder.json?.canonical_status || String(customerOrder.status) },
    );

    const hops = [
      'EN_ROUTE_PICKUP',
      'ARRIVED_PICKUP',
      'PICKED_UP',
      'IN_TRANSIT',
    ];
    let lastStatus = 'ASSIGNED';
    for (const to of hops) {
      const hop = await http('POST', `/v1/rider/orders/${orderId}/status`, {
        token: riderToken,
        body: { to_status: to },
      });
      lastStatus = hop.json?.canonical_status || lastStatus;
      if (hop.status !== 200) {
        step(`rider_status_${to}`, false, {
          detail: `${hop.status} ${hop.json?.error?.code || ''}`,
        });
        break;
      }
    }
    step('rider_status_hops', lastStatus === 'IN_TRANSIT', {
      detail: lastStatus,
    });

    const customerAfter = await http('GET', `/v1/orders/${orderId}`, {
      token: customerToken,
    });
    step(
      'customer_sees_status',
      customerAfter.json?.canonical_status === lastStatus,
      { detail: customerAfter.json?.canonical_status || String(customerAfter.status) },
    );

    const adminAfter = await http('GET', `/v1/admin/orders/${orderId}`, {
      token: adminToken,
    });
    step('admin_sees_status', adminAfter.json?.canonical_status === lastStatus, {
      detail: adminAfter.json?.canonical_status || String(adminAfter.status),
    });

    const notices = await client.query(
      `SELECT count(*)::int AS n FROM notifications WHERE order_id = $1`,
      [orderId],
    );
    step('notifications_exist', (notices.rows[0]?.n || 0) > 0, {
      detail: `count ${notices.rows[0]?.n || 0}`,
    });

    const offerDb = await client.query(
      `SELECT status FROM order_offers WHERE order_offer_id = $1`,
      [offerId],
    );
    step('offer_accepted_in_db', offerDb.rows[0]?.status === 'ACCEPTED', {
      detail: offerDb.rows[0]?.status || 'missing',
    });
  }
} catch (err) {
  step('script_error', false, {
    detail: err instanceof Error ? err.message : 'unknown',
  });
  process.exitCode = 1;
} finally {
  await client.end();
  const failed = report.filter((item) => !item.ok);
  console.log(`\n${report.length - failed.length}/${report.length} checks passed`);
  if (failed.length > 0) {
    process.exitCode = 1;
  }
}
