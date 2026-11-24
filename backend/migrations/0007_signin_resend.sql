alter table signin_challenges add column sent_at timestamptz not null default now(), add column resends integer not null default 0 check (resends between 0 and 2);
