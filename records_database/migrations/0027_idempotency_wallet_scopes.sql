-- Allow wallet top-up / withdrawal idempotency scopes used by PaymentsService and WalletCodService.
-- Migration 0026 introduced those flows but did not extend idempotency_scope_chk.

ALTER TABLE idempotency_keys
  DROP CONSTRAINT idempotency_scope_chk;

ALTER TABLE idempotency_keys
  ADD CONSTRAINT idempotency_scope_chk CHECK (scope IN (
    'create-order',
    'accept-offer',
    'payment',
    'webhook',
    'recharge',
    'cod-settlement',
    'cancel',
    'resend',
    'invoice',
    'status',
    'finance-freeze',
    'wallet-topup',
    'wallet-withdraw'
  ));
