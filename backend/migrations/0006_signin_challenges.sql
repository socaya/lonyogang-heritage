create table signin_challenges (
 token_hash bytea primary key,
 account_id uuid not null references accounts(id) on delete cascade,
 device_id uuid not null,
 user_agent text,
 method text not null check (method in ('email','totp')),
 code_hash bytea,
 credential_version text not null,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null,
 consumed_at timestamptz,
 attempts integer not null default 0 check (attempts >= 0),
 check ((method='email' and code_hash is not null) or (method='totp' and code_hash is null))
);
create index signin_challenges_account_created on signin_challenges(account_id,created_at);
create table signin_totp_replays (
 account_id uuid not null references accounts(id) on delete cascade,
 code_hash bytea not null,
 expires_at timestamptz not null,
 primary key(account_id,code_hash)
);
