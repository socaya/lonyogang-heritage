-- Persistence for weekly transparency anchors produced by TransparencyService.

create table transparency_anchors (
  id            uuid primary key default gen_random_uuid(),
  account_id    uuid references accounts(id) on delete cascade,
  anchor_scope  text not null check (anchor_scope in ('account', 'global')),
  tip_hash      bytea not null,
  entry_count   bigint not null,
  verified      boolean not null,
  broken_at     text,
  anchor_proof  bytea,
  anchor_source text,
  created_at    timestamptz not null default now()
);

create index on transparency_anchors(account_id, created_at desc);
create index on transparency_anchors(anchor_scope, created_at desc);

insert into schema_migrations(version) values ('0002_transparency_anchors');
