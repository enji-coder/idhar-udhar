SELECT n.nspname AS schema, c.contype, COUNT(*) AS n
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
GROUP BY n.nspname, c.contype
ORDER BY c.contype;

SELECT COUNT(*) AS public_indexes
FROM pg_indexes WHERE schemaname = 'public';

SELECT COUNT(*) AS unique_indexes
FROM pg_indexes
WHERE schemaname = 'public' AND indexdef ILIKE '%UNIQUE%';

SELECT COUNT(*) AS deferrable_fks
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'public' AND contype = 'f' AND condeferrable;

SELECT COUNT(*) AS cascade_delete_fks
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'public' AND contype = 'f' AND confdeltype = 'c';

SELECT COUNT(*) AS set_null_delete_fks
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'public' AND contype = 'f' AND confdeltype = 'n';

SELECT t.relname AS table_name, a.attname, y.typname
FROM pg_attribute a
JOIN pg_class t ON t.oid = a.attrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_type y ON y.oid = a.atttypid
WHERE n.nspname = 'public' AND a.attnum > 0 AND NOT a.attisdropped
  AND y.typname IN ('float4', 'float8');

SELECT to_regclass('public.rider_location_samples') AS gps_table;
