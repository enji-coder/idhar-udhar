-- Immutability, stop shape, plan-vs-responsibility, resend parent/child, payment status, config publish.

-- Append-only / no-delete tables
CREATE TRIGGER wallet_ledger_immutable
  BEFORE UPDATE OR DELETE ON wallet_ledger_entries
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER cod_ledger_immutable
  BEFORE UPDATE OR DELETE ON cod_ledger_entries
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER customer_wallet_ledger_immutable
  BEFORE UPDATE OR DELETE ON customer_wallet_ledger_entries
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER order_fare_snapshots_immutable
  BEFORE UPDATE OR DELETE ON order_fare_snapshots
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER order_finance_snapshots_immutable
  BEFORE UPDATE OR DELETE ON order_finance_snapshots
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER order_cancellation_snapshots_immutable
  BEFORE UPDATE OR DELETE ON order_cancellation_snapshots
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER failed_deliveries_immutable
  BEFORE UPDATE OR DELETE ON failed_deliveries
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER order_adjustments_immutable
  BEFORE UPDATE OR DELETE ON order_adjustments
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER order_status_events_immutable
  BEFORE UPDATE OR DELETE ON order_status_events
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER audit_logs_immutable
  BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER invoice_lines_immutable
  BEFORE UPDATE OR DELETE ON invoice_lines
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER payment_resp_immutable
  BEFORE UPDATE OR DELETE ON order_payment_responsibilities
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER payment_plan_immutable
  BEFORE UPDATE OR DELETE ON order_payment_plans
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER fare_quotes_amounts_immutable
  BEFORE UPDATE ON fare_quotes
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE TRIGGER idempotency_keys_immutable
  BEFORE UPDATE OR DELETE ON idempotency_keys
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE OR REPLACE FUNCTION forbid_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION '% rows cannot be deleted', TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE TRIGGER rider_wallet_no_delete
  BEFORE DELETE ON rider_wallet_accounts
  FOR EACH ROW EXECUTE FUNCTION forbid_delete();

CREATE TRIGGER rider_cod_no_delete
  BEFORE DELETE ON rider_cod_accounts
  FOR EACH ROW EXECUTE FUNCTION forbid_delete();

CREATE TRIGGER customer_wallet_no_delete
  BEFORE DELETE ON customer_wallet_accounts
  FOR EACH ROW EXECUTE FUNCTION forbid_delete();

CREATE TRIGGER orders_no_delete
  BEFORE DELETE ON orders
  FOR EACH ROW EXECUTE FUNCTION forbid_delete();

CREATE TRIGGER invoices_no_delete
  BEFORE DELETE ON invoices
  FOR EACH ROW EXECUTE FUNCTION forbid_delete();

CREATE OR REPLACE FUNCTION payment_transactions_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'payment_transactions cannot be deleted'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF NEW.payment_transaction_id IS DISTINCT FROM OLD.payment_transaction_id
     OR NEW.order_id IS DISTINCT FROM OLD.order_id
     OR NEW.payer_type IS DISTINCT FROM OLD.payer_type
     OR NEW.method IS DISTINCT FROM OLD.method
     OR NEW.amount IS DISTINCT FROM OLD.amount
     OR NEW.direction IS DISTINCT FROM OLD.direction
     OR NEW.provider_txn_id IS DISTINCT FROM OLD.provider_txn_id
     OR NEW.provider_event_id IS DISTINCT FROM OLD.provider_event_id
     OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
     OR NEW.created_by_type IS DISTINCT FROM OLD.created_by_type
     OR NEW.created_by_profile_id IS DISTINCT FROM OLD.created_by_profile_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'payment_transactions identity/money columns are immutable'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.transaction_status IS NOT DISTINCT FROM NEW.transaction_status THEN
    RETURN NEW;
  END IF;
  IF OLD.transaction_status = 'PENDING' AND NEW.transaction_status IN ('PAID', 'FAILED') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'illegal payment transaction_status transition % -> %',
    OLD.transaction_status, NEW.transaction_status
    USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER payment_transactions_guard
  BEFORE UPDATE OR DELETE ON payment_transactions
  FOR EACH ROW EXECUTE FUNCTION payment_transactions_guard();

CREATE OR REPLACE FUNCTION resend_snapshots_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'resend_snapshots cannot be deleted'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF NEW.resend_snapshot_id IS DISTINCT FROM OLD.resend_snapshot_id
     OR NEW.original_order_id IS DISTINCT FROM OLD.original_order_id
     OR NEW.child_order_id IS DISTINCT FROM OLD.child_order_id
     OR NEW.resend_case IS DISTINCT FROM OLD.resend_case
     OR NEW.distance_km IS DISTINCT FROM OLD.distance_km
     OR NEW.case_a_base_fare IS DISTINCT FROM OLD.case_a_base_fare
     OR NEW.customer_amount IS DISTINCT FROM OLD.customer_amount
     OR NEW.rider_amount IS DISTINCT FROM OLD.rider_amount
     OR NEW.company_amount IS DISTINCT FROM OLD.company_amount
     OR NEW.fare_config_version_id IS DISTINCT FROM OLD.fare_config_version_id
     OR NEW.extra_rate_version_id IS DISTINCT FROM OLD.extra_rate_version_id
     OR NEW.payment_settings_version_id IS DISTINCT FROM OLD.payment_settings_version_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'resend_snapshots money/version columns are immutable'
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER resend_snapshots_guard
  BEFORE UPDATE OR DELETE ON resend_snapshots
  FOR EACH ROW EXECUTE FUNCTION resend_snapshots_guard();

CREATE OR REPLACE FUNCTION invoices_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.invoice_id IS DISTINCT FROM OLD.invoice_id
     OR NEW.invoice_number IS DISTINCT FROM OLD.invoice_number
     OR NEW.order_id IS DISTINCT FROM OLD.order_id
     OR NEW.trip_fare IS DISTINCT FROM OLD.trip_fare
     OR NEW.discount IS DISTINCT FROM OLD.discount
     OR NEW.additional_locked_charges IS DISTINCT FROM OLD.additional_locked_charges
     OR NEW.rounding IS DISTINCT FROM OLD.rounding
     OR NEW.billed_total IS DISTINCT FROM OLD.billed_total
     OR NEW.customer_paid IS DISTINCT FROM OLD.customer_paid
     OR NEW.receiver_paid IS DISTINCT FROM OLD.receiver_paid
     OR NEW.gst_on_fare IS DISTINCT FROM OLD.gst_on_fare
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'invoice identity and amount columns are immutable'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.status = 'CANCELLED' AND NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION 'cancelled invoice status cannot change'
      USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.status = 'ISSUED' AND NEW.status NOT IN ('ISSUED', 'CANCELLED') THEN
    RAISE EXCEPTION 'issued invoice may only move to CANCELLED'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER invoices_guard
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION invoices_guard();

CREATE OR REPLACE FUNCTION notifications_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  IF NEW.notification_id IS DISTINCT FROM OLD.notification_id
     OR NEW.recipient_identity_id IS DISTINCT FROM OLD.recipient_identity_id
     OR NEW.recipient_profile_type IS DISTINCT FROM OLD.recipient_profile_type
     OR NEW.customer_profile_id IS DISTINCT FROM OLD.customer_profile_id
     OR NEW.rider_profile_id IS DISTINCT FROM OLD.rider_profile_id
     OR NEW.admin_profile_id IS DISTINCT FROM OLD.admin_profile_id
     OR NEW.type IS DISTINCT FROM OLD.type
     OR NEW.title IS DISTINCT FROM OLD.title
     OR NEW.body IS DISTINCT FROM OLD.body
     OR NEW.order_id IS DISTINCT FROM OLD.order_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'notifications content is immutable; only read_at may change'
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER notifications_guard
  BEFORE UPDATE ON notifications
  FOR EACH ROW EXECUTE FUNCTION notifications_guard();

CREATE OR REPLACE FUNCTION protect_published_config()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status IN ('ACTIVE', 'SUPERSEDED') THEN
    IF (to_jsonb(NEW) - 'status' - 'effective_until')
         IS DISTINCT FROM (to_jsonb(OLD) - 'status' - 'effective_until') THEN
      RAISE EXCEPTION '% published payload is immutable; publish version N+1 instead', TG_TABLE_NAME
        USING ERRCODE = 'restrict_violation';
    END IF;
    IF NEW.status NOT IN ('ACTIVE', 'SUPERSEDED') THEN
      RAISE EXCEPTION 'published config cannot return to DRAFT'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER fare_config_protect_published
  BEFORE UPDATE ON fare_config_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

CREATE TRIGGER payment_settings_protect_published
  BEFORE UPDATE ON payment_settings_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

CREATE TRIGGER payment_method_protect_published
  BEFORE UPDATE ON payment_method_policy_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

CREATE TRIGGER cancellation_config_protect_published
  BEFORE UPDATE ON cancellation_config_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

CREATE TRIGGER cod_policy_protect_published
  BEFORE UPDATE ON cod_policy_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

CREATE TRIGGER extra_rate_protect_published
  BEFORE UPDATE ON extra_rate_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

CREATE TRIGGER company_office_protect_published
  BEFORE UPDATE ON company_office_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

CREATE OR REPLACE FUNCTION protect_published_fare_rates()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT status INTO v_status FROM fare_config_versions WHERE fare_config_version_id = OLD.fare_config_version_id;
    IF v_status IN ('ACTIVE', 'SUPERSEDED') THEN
      RAISE EXCEPTION 'cannot delete rates of a published fare version'
        USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN OLD;
  END IF;
  SELECT status INTO v_status FROM fare_config_versions WHERE fare_config_version_id = NEW.fare_config_version_id;
  IF v_status IN ('ACTIVE', 'SUPERSEDED') THEN
    RAISE EXCEPTION 'cannot change rates of a published fare version'
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER fare_rates_protect_published
  BEFORE INSERT OR UPDATE OR DELETE ON fare_config_version_rates
  FOR EACH ROW EXECUTE FUNCTION protect_published_fare_rates();

CREATE OR REPLACE FUNCTION protect_published_cancel_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status TEXT;
  v_id UUID;
BEGIN
  v_id := COALESCE(NEW.cancellation_config_version_id, OLD.cancellation_config_version_id);
  SELECT status INTO v_status FROM cancellation_config_versions WHERE cancellation_config_version_id = v_id;
  IF v_status IN ('ACTIVE', 'SUPERSEDED') THEN
    RAISE EXCEPTION 'cannot change rules of a published cancellation version'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER cancel_rules_protect_published
  BEFORE INSERT OR UPDATE OR DELETE ON cancellation_config_version_rules
  FOR EACH ROW EXECUTE FUNCTION protect_published_cancel_rules();

CREATE OR REPLACE FUNCTION enforce_order_stop_shape()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_order UUID;
  pickup_count INTEGER;
  drop_count INTEGER;
BEGIN
  v_order := COALESCE(NEW.order_id, OLD.order_id);
  SELECT
    count(*) FILTER (WHERE stop_type = 'PICKUP'),
    count(*) FILTER (WHERE stop_type = 'DROP')
  INTO pickup_count, drop_count
  FROM order_stops
  WHERE order_id = v_order;

  IF pickup_count <> 1 THEN
    RAISE EXCEPTION 'order % must have exactly 1 PICKUP (found %)', v_order, pickup_count
      USING ERRCODE = 'check_violation';
  END IF;
  IF drop_count < 1 OR drop_count > 3 THEN
    RAISE EXCEPTION 'order % must have 1 to 3 DROP stops (found %)', v_order, drop_count
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER order_stops_shape
  AFTER INSERT OR UPDATE OR DELETE ON order_stops
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION enforce_order_stop_shape();

CREATE CONSTRAINT TRIGGER orders_require_stops
  AFTER INSERT ON orders
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION enforce_order_stop_shape();

CREATE OR REPLACE FUNCTION enforce_payment_plan_matches_responsibility()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  r order_payment_responsibilities%ROWTYPE;
BEGIN
  SELECT * INTO r
  FROM order_payment_responsibilities
  WHERE order_id = NEW.order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'payment plan requires responsibility for order %', NEW.order_id
      USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.customer_planned_online + NEW.customer_planned_cash <> r.customer_responsibility THEN
    RAISE EXCEPTION 'customer planned methods must equal customer responsibility'
      USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.receiver_planned_online + NEW.receiver_planned_cash <> r.receiver_responsibility THEN
    RAISE EXCEPTION 'receiver planned methods must equal receiver responsibility'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER payment_plan_matches_responsibility
  AFTER INSERT ON order_payment_plans
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION enforce_payment_plan_matches_responsibility();

CREATE OR REPLACE FUNCTION enforce_resend_child_parent()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_parent UUID;
BEGIN
  IF NEW.child_order_id IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT parent_order_id INTO v_parent FROM orders WHERE order_id = NEW.child_order_id;
  IF v_parent IS DISTINCT FROM NEW.original_order_id THEN
    RAISE EXCEPTION 'resend child_order_id must have parent_order_id = original_order_id'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER resend_child_parent_match
  AFTER INSERT OR UPDATE OF child_order_id, original_order_id ON resend_snapshots
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION enforce_resend_child_parent();
