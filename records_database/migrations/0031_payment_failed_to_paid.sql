-- Allow an authoritative verified SUCCESS to recover a premature FAILED charge.
-- The trigger created in 0014 already calls payment_transactions_guard();
-- replacing the function is enough for databases that already applied 0014.
-- Identity and money columns stay immutable. Every other status change stays illegal.

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
  IF OLD.transaction_status = 'FAILED' AND NEW.transaction_status = 'PAID' THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'illegal payment transaction_status transition % -> %',
    OLD.transaction_status, NEW.transaction_status
    USING ERRCODE = 'check_violation';
END;
$$;
