-- Record successful registration proof independently from invalidation.
alter table account_verifications add column verified_at timestamptz;
alter table account_verifications add column attempts integer not null default 0 check (attempts >= 0);
-- Under the legacy implementation, pending-account consumed records were
-- created only by successful verification; resets were issued to active accounts.
update account_verifications v set verified_at=v.consumed_at
from accounts a where a.id=v.account_id and a.status='pending' and v.consumed_at is not null;
create index account_verifications_verified on account_verifications(account_id,channel) where verified_at is not null;
