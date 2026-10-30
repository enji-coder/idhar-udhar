# Staging master data

These templates are not seeds. Do not POST them until a business owner replaces every placeholder. Do not insert zero fares to make a booking screen load. Do not copy production rows.

The API launch lookup is an active city whose `city_code` is `AMD`. Migration `0025` inserts Gujarat (`GJ`) only. It does not insert Ahmedabad.

## Authorization

`POST /v1/admin/auth/login` with `{ "email", "password" }` returns a bearer token. The session role is `ADMIN`. City and vehicle-category routes use `@Roles('ADMIN')`, so that token is enough. Creating the admin itself is `backend/scripts/create-staging-admin.mjs`. Do not run `create-production-admin.mjs`.

## 1. Gujarat state id

```http
GET /v1/admin/states
Authorization: Bearer <staging-admin-access-token>
```

Copy the `state_id` whose `code` is `GJ` into `docs/staging/city.template.json`. Do not create a second Gujarat row.

## 2. Launch city

`POST /v1/admin/cities`

Body shape (`CreateCityDto`):

- `state_id` — UUID, required
- `name` — 1–80 characters
- `city_code` — 2–5 letters, stored uppercase. Use `AMD` for the launch city.
- `active` — optional, default true

Template: `docs/staging/city.template.json`.

## 3. Vehicle category and fare

`POST /v1/admin/vehicle-categories`

`name` is the only required field. The launch city is not part of this body. The service publishes the category on the active `AMD` city.

Allowed pairs:

- `two_wheeler`: `bike`, `scooty`
- `three_wheeler`: `loader_riksha`
- `truck`: `mini_truck`, `tempo`, `large_tempo`, `truck`

Send `vehicle_type` and `vehicle` together, or omit both.

Template: `docs/staging/vehicle-category.template.json`. Replace every `<...>` value before use. String placeholders fail numeric validation on purpose.

If any fare amount is greater than zero, a fare version is published. When the percentages are omitted, the API stores rider `85.00` and company `15.00`. That pair is a code default, not an approved commercial split. Send both percentages, and they must add up to 100. Sending only one percentage is rejected.

`waiting` is a flat amount. `waiting_charge_per_minute` is the per-minute charge. `initial_waiting_minutes` is an integer from 0 to 1440. `initial_minimum` defaults to `base_fare` when omitted.

Leave `rates` out only when the category should exist without a published fare. A booking quote still needs an approved published fare. Do not send a `rates` object of zeros.

## Admin CORS

Staging task definition `idhar-udhar-staging-api:3` allows only:

- `http://localhost:5173`
- `http://127.0.0.1:5173`

`NODE_ENV` on that task is `production`, so the API does not add extra loopback origins. Vite's default `npm run dev` origin is `http://localhost:5173`, which is already allowed. Point `IDHAR_UDHAR_ADMIN/.env.staging` at `https://staging-api.idharudhar.co.in` and run Admin on port 5173. `IDHAR_UDHAR_ADMIN/.env.example` stays on `https://api.idharudhar.co.in`.

No staging hosted Admin origin is defined. `https://admin.idharudhar.co.in` is the production Admin origin and must not be added to staging. A different local port, such as `http://localhost:5174`, is also rejected.

If a hosted staging Admin is approved later, the minimal change is one new staging task definition whose `CORS_ORIGIN` is the two localhost origins plus that exact staging origin. Do not change the production task definition.

## Staging admin bootstrap

`npm run admin:staging:create` in `backend/` runs `scripts/create-staging-admin.mjs`. It is not the production script. It does not load `.env` files. Do not execute it until the staging write is approved.

Required environment, and nothing inferred from `NODE_ENV`:

- `IU_DEPLOYMENT_TIER=staging`
- `DATABASE_HOST=iu-staging-db.crc48wu0snqv.ap-south-1.rds.amazonaws.com`
- `DATABASE_NAME=idhar_udhar_staging`
- `DATABASE_USER`, `DATABASE_PASSWORD`, and `DATABASE_SSL=true` with the RDS CA path
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD` (at least 8 characters; omitted from dry-run)
- `STAGING_ADMIN_CONFIRM=create-staging-admin` for a real create

`STAGING_ADMIN_DRY_RUN=1` opens a read-only transaction, checks `current_database()`, and prints `dry_run` or `already_present`. It does not insert. A second admin email, an existing non-admin identity, and any password change are refused. The same active `SUPER_ADMIN` email is a no-op.

## Business inputs still required

- Staging admin email and password, supplied only in the process environment.
- Confirmation that Ahmedabad / `AMD` is the staging launch city.
- Each category name, code, vehicle pair, and every fare field above, including both commission percentages.
