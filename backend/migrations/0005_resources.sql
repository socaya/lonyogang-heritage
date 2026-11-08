-- Per-entity resource state used by the REST layer at /resources/:kind.
--
-- The /sync/events stream is append-only and ideal for cross-device
-- replay, but a web client that wants "give me the current state of
-- asset X" should not have to scan the entire event log. This table
-- holds the latest-known ciphertext + integrity hint for every
-- (account, kind, id) tuple and is written alongside the matching
-- /sync/events row so both views stay consistent.
--
-- The server still never sees plaintext: `ciphertext` is AES-GCM under
-- the client's content key, `integrity` is a small plaintext map the
-- client supplies for cross-field invariants (e.g. combined_bps=10000
-- on beneficiaries) and `prev_hash` chains the device-side history.
create table if not exists resources (
  account_id  uuid        not null references accounts(id) on delete cascade,
  kind        text        not null,
  id          text        not null,
  ciphertext  bytea       not null,
  integrity   jsonb,
  prev_hash   bytea,
  device_id   uuid        not null,
  version     bigint      not null default 1,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  primary key (account_id, kind, id)
);

create index if not exists idx_resources_account_kind_updated
  on resources(account_id, kind, updated_at desc)
  where deleted_at is null;

create index if not exists idx_resources_account_updated
  on resources(account_id, updated_at desc);

insert into schema_migrations(version) values ('0005_resources');
