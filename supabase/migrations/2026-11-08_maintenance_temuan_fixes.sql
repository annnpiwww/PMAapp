-- ==============================================================================
-- Migration: 2026-11-08_maintenance_temuan_fixes.sql
-- Description: Creates the insert-only table for maintenance temuan fixes.
-- Notice: FILE ONLY. Do NOT apply automatically to any database.
--         This migration must be applied manually with repository owner approval.
-- Pattern: Insert-only table. No UPDATE or DELETE policies are granted to preserve
--          audit integrity and prevent log sync overwrites.
-- ==============================================================================

create table if not exists public.maintenance_temuan_fixes (
  id text primary key,
  log_id text not null,
  temuan_label text not null,
  pos_id text not null,
  pos_name text not null default '',
  branch text not null default 'MDO',
  teknisi_nama text not null,
  teknisi_npp text default '',
  catatan text not null,
  photo_urls jsonb not null default '[]'::jsonb,
  fixed_at timestamptz not null default now(),
  created_at timestamptz default now(),
  unique (log_id, temuan_label),
  check (char_length(catatan) between 3 and 500),
  check (jsonb_typeof(photo_urls) = 'array' and jsonb_array_length(photo_urls) between 1 and 3)
);

-- Indexes for performant filtering
create index if not exists idx_maintenance_temuan_fixes_log_id
  on public.maintenance_temuan_fixes (log_id);

create index if not exists idx_maintenance_temuan_fixes_branch
  on public.maintenance_temuan_fixes (branch);

-- Enable Row Level Security (RLS)
alter table public.maintenance_temuan_fixes enable row level security;

-- Policies: SELECT and INSERT only (insert-only design)
drop policy if exists "maintenance_temuan_fixes_select" on public.maintenance_temuan_fixes;
create policy "maintenance_temuan_fixes_select"
  on public.maintenance_temuan_fixes
  for select
  to anon, authenticated
  using (true);

drop policy if exists "maintenance_temuan_fixes_insert" on public.maintenance_temuan_fixes;
create policy "maintenance_temuan_fixes_insert"
  on public.maintenance_temuan_fixes
  for insert
  to anon, authenticated
  with check (true);

-- Permissions: grant SELECT, INSERT only to anon & authenticated
grant select, insert on public.maintenance_temuan_fixes to anon, authenticated;
