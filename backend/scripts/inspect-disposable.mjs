import pg from 'pg';

const client = new pg.Client({
  host: '127.0.0.1',
  port: 54329,
  database: 'idhar_udhar_disposable',
  user: 'disposable',
  password: 'disposable',
});
await client.connect();
const rows = await client.query(`
  SELECT o.canonical_status, (o.removed_from_operations_at IS NOT NULL) AS hidden,
         s.trip_fare::text, s.snapshot_kind
  FROM order_finance_snapshots s
  JOIN orders o ON o.order_id = s.order_id
`);
console.log(JSON.stringify(rows.rows));
const tax = await client.query(`SELECT count(*)::text AS n FROM tax_config_versions`);
console.log('tax', tax.rows[0].n);
await client.end();
