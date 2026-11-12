-- Migration: Add admin_pos columns to public.app_users
-- Contract: docs/contracts/admin-lapor.md

alter table public.app_users
  add column if not exists pos_name text,
  add column if not exists pos_kode text,
  add column if not exists aktif boolean not null default true,
  alter column id set default ('usr_' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)),
  alter column email drop not null,
  alter column email drop default,
  alter column password drop not null;

comment on column public.app_users.pos_name is
  'Fixed POS marker name (matches pos_locations.pos_name) for role=admin_pos accounts.';
comment on column public.app_users.pos_kode is
  'Short lowercase location code ([a-z0-9]{2,10}) used in admin_pos username <nama-slug>-<pos_kode>.';
comment on column public.app_users.aktif is
  'Active flag for admin_pos accounts; false blocks auth-login and daily-tasks admin_report.';
