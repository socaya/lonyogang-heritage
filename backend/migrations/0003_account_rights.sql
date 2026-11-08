-- Account fields backing the DPPA 2019 compliance claims:
--   * marketing_consent_at   — null means consent not given.
--   * closed_at              — set when the user exercises right-to-erasure.
--   * failed_login_count     — rolling counter for lockout.
--   * locked_until            — short-term soft lockout window.
alter table accounts
  add column marketing_consent_at timestamptz,
  add column closed_at            timestamptz,
  add column failed_login_count   integer not null default 0,
  add column locked_until         timestamptz;

create index on accounts(closed_at) where closed_at is null;

insert into schema_migrations(version) values ('0003_account_rights');
