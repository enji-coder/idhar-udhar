-- Remaining FK btree indexes (PostgreSQL does not index FKs automatically).
-- Skip columns already unique or already indexed.

CREATE INDEX customer_profiles_default_city_idx ON customer_profiles (default_city_id);
CREATE INDEX rider_profiles_home_zone_idx ON rider_profiles (home_zone_id);
CREATE INDEX admin_profiles_city_scope_idx ON admin_profiles (city_scope_id);
CREATE INDEX sessions_customer_profile_idx ON sessions (customer_profile_id);
CREATE INDEX sessions_rider_profile_idx ON sessions (rider_profile_id);
CREATE INDEX sessions_admin_profile_idx ON sessions (admin_profile_id);
CREATE INDEX saved_addresses_zone_idx ON customer_saved_addresses (zone_id);
CREATE INDEX stored_files_created_by_idx ON stored_files (created_by_identity_id);
CREATE INDEX rider_documents_file_idx ON rider_documents (file_id);
CREATE INDEX vehicle_documents_file_idx ON vehicle_documents (file_id);
CREATE INDEX fare_config_created_by_idx ON fare_config_versions (created_by_admin_profile_id);
CREATE INDEX fare_quotes_version_idx ON fare_quotes (fare_config_version_id);
CREATE INDEX fare_quotes_category_idx ON fare_quotes (vehicle_category_id);
CREATE INDEX order_fare_snapshots_version_idx ON order_fare_snapshots (fare_config_version_id);
CREATE INDEX payment_settings_created_by_idx ON payment_settings_versions (created_by_admin_profile_id);
CREATE INDEX extra_rate_created_by_idx ON extra_rate_versions (created_by_admin_profile_id);
CREATE INDEX company_office_created_by_idx ON company_office_versions (created_by_admin_profile_id);
CREATE INDEX order_stops_zone_idx ON order_stops (zone_id);
CREATE INDEX order_stops_proof_idx ON order_stops (proof_file_id);
CREATE INDEX finance_snap_settings_idx ON order_finance_snapshots (payment_settings_version_id);
CREATE INDEX invoices_pdf_idx ON invoices (pdf_file_id);
CREATE INDEX notifications_order_idx ON notifications (order_id);
CREATE INDEX resend_extra_rate_idx ON resend_snapshots (extra_rate_version_id);
CREATE INDEX order_adj_extra_rate_idx ON order_adjustments (extra_rate_version_id);
CREATE INDEX wallet_ledger_cod_twin_idx ON wallet_ledger_entries (related_cod_ledger_id);
CREATE INDEX wallet_ledger_order_idx ON wallet_ledger_entries (related_order_id);
CREATE INDEX cod_ledger_wallet_twin_idx ON cod_ledger_entries (related_wallet_ledger_id);
CREATE INDEX fare_config_rates_category_idx ON fare_config_version_rates (vehicle_category_id);
