-- Separate password reset tokens from registration codes. Legacy outstanding
-- reset links are intentionally invalidated; users must request a new link.
create table password_reset_tokens (
  token_hash bytea primary key,
  account_id uuid not null references accounts(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);
create index password_reset_tokens_account_created on password_reset_tokens(account_id, created_at desc);
-- Active/locked/closed accounts have no pending registration requirement.
update account_verifications v set consumed_at = now()
from accounts a where a.id = v.account_id and a.status <> 'pending' and v.consumed_at is null;
