-- Security + robustness hardening.

-- Faster lookups for account_verifications by account+channel+not-consumed.
create index if not exists idx_account_verifications_open
  on account_verifications(account_id, channel, consumed_at);

-- Idempotency log for payment-provider webhooks so a retry can be
-- accepted at the HTTP layer and short-circuited before PaymentsService
-- touches the subscription row twice.
create table if not exists webhook_idempotency (
  provider      text not null,
  external_ref  text not null,
  received_at   timestamptz not null default now(),
  primary key (provider, external_ref)
);

insert into schema_migrations(version) values ('0004_security_hardening');
