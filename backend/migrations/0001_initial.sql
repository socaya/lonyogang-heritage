-- Initial schema for the LonyoGang Heritage backend.
-- Matches docs/ONLINE_SERVICE_PLAN.md §5.

create extension if not exists citext;
create extension if not exists pgcrypto;

create table accounts (
  id            uuid primary key default gen_random_uuid(),
  email         citext not null unique,
  phone         text,
  display_name  text,
  password_hash text,              -- argon2id, nullable until password set
  totp_secret   text,              -- encrypted at rest via KMS envelope
  status        text not null default 'pending'
                 check (status in ('pending','active','locked','closed')),
  created_at    timestamptz not null default now(),
  verified_at   timestamptz,
  locked_at     timestamptz
);

create table account_verifications (
  id         uuid primary key default gen_random_uuid(),
  account_id uuid not null references accounts(id) on delete cascade,
  channel    text not null check (channel in ('email','phone')),
  code_hash  bytea not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index on account_verifications(account_id, channel);

create table sessions (
  id            uuid primary key default gen_random_uuid(),
  account_id    uuid not null references accounts(id) on delete cascade,
  device_id     uuid not null,
  refresh_hash  bytea not null,
  user_agent    text,
  created_at    timestamptz not null default now(),
  refreshed_at  timestamptz,
  expires_at    timestamptz not null,
  revoked_at    timestamptz
);

create index on sessions(account_id, device_id);

create table passkeys (
  id              uuid primary key default gen_random_uuid(),
  account_id      uuid not null references accounts(id) on delete cascade,
  credential_id   bytea not null unique,
  public_key      bytea not null,
  counter         bigint not null default 0,
  transports      text[] not null default '{}',
  aaguid          uuid,
  friendly_name   text,
  created_at      timestamptz not null default now(),
  last_used_at    timestamptz
);

create index on passkeys(account_id);

create table webauthn_challenges (
  id            uuid primary key default gen_random_uuid(),
  account_id    uuid references accounts(id) on delete cascade,
  challenge     bytea not null,
  kind          text not null check (kind in ('registration','authentication')),
  expires_at    timestamptz not null,
  created_at    timestamptz not null default now()
);

create table vault_envelopes (
  account_id            uuid primary key references accounts(id) on delete cascade,
  wrapped_content_key   bytea not null,
  server_recovery_share bytea,                        -- shamir share, KMS-sealed
  recovery_sheet_hash   bytea,                        -- hash of printable share
  version               int not null default 1,
  rotated_at            timestamptz not null default now()
);

create table events (
  id            text primary key,                     -- ULID from the client
  account_id    uuid not null references accounts(id) on delete cascade,
  device_id     uuid not null,
  payload_type  text not null,
  payload       bytea not null,
  prev_hash     bytea,
  hash          bytea not null,
  integrity     jsonb,                                -- plaintext safety signals (e.g. beneficiary share totals)
  created_at    timestamptz not null default now(),
  received_at   timestamptz not null default now()
);

create index on events(account_id, received_at);
create index on events(account_id, payload_type);

create table attachment_blobs (
  id          uuid primary key default gen_random_uuid(),
  account_id  uuid not null references accounts(id) on delete cascade,
  bucket_key  text not null unique,
  size_bytes  bigint not null,
  sha256      bytea not null,
  mime_type   text,
  uploaded_at timestamptz,
  created_at  timestamptz not null default now()
);

create index on attachment_blobs(account_id);

create table audit_entries (
  id            text primary key,                     -- ULID
  account_id    uuid references accounts(id) on delete cascade,
  actor_kind    text not null check (actor_kind in ('user','service','admin','system')),
  actor_id      text,
  action        text not null,
  resource      text,
  context       jsonb,
  prev_hash     bytea,
  hash          bytea not null,
  created_at    timestamptz not null default now()
);

create index on audit_entries(account_id, created_at);
create index on audit_entries(action);

create table fx_rates_cache (
  currency     text not null,
  as_of        date not null,
  ugx_per_unit bigint not null,
  source       text not null,
  cached_at    timestamptz not null default now(),
  primary key (currency, as_of)
);

create table bank_connections (
  id            uuid primary key default gen_random_uuid(),
  account_id    uuid not null references accounts(id) on delete cascade,
  provider      text not null,
  external_id   text not null,
  display_label text,
  scopes        text[] not null default '{}',
  status        text not null default 'linked'
                 check (status in ('linked','paused','revoked','error')),
  linked_at     timestamptz not null default now(),
  revoked_at    timestamptz,
  last_sync_at  timestamptz,
  secret_cipher bytea,                                 -- KMS-sealed provider token
  unique (account_id, provider, external_id)
);

create table bank_transactions (
  id              uuid primary key default gen_random_uuid(),
  connection_id   uuid not null references bank_connections(id) on delete cascade,
  external_ref    text not null,
  occurred_at     timestamptz not null,
  amount_ugx      bigint not null,
  description     text,
  raw             jsonb,
  imported_event  text references events(id) on delete set null,
  unique (connection_id, external_ref)
);

create table subscriptions (
  account_id    uuid primary key references accounts(id) on delete cascade,
  tier          text not null default 'free'
                 check (tier in ('free','heritage','family')),
  provider      text,
  external_ref  text,
  status        text not null default 'active'
                 check (status in ('active','trialing','past_due','canceled')),
  current_period_end timestamptz,
  updated_at    timestamptz not null default now()
);

create table payment_events (
  id            uuid primary key default gen_random_uuid(),
  account_id    uuid references accounts(id) on delete cascade,
  provider      text not null,
  external_ref  text not null,
  kind          text not null,
  payload       jsonb not null,
  received_at   timestamptz not null default now()
);

create table push_tokens (
  id            uuid primary key default gen_random_uuid(),
  account_id    uuid not null references accounts(id) on delete cascade,
  device_id     uuid not null,
  platform      text not null check (platform in ('fcm','apns')),
  token         text not null,
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  unique (device_id, platform)
);

create table schema_migrations (
  version     text primary key,
  applied_at  timestamptz not null default now()
);

insert into schema_migrations(version) values ('0001_initial');
