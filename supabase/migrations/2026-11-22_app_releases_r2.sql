-- Migration: 2026-11-22_app_releases_r2.sql
-- PMApp updater storage backend: track legacy 'supabase' rows vs new 'r2' uploads.

alter table public.app_releases
  add column if not exists backend text not null default 'supabase';

alter table public.app_releases
  drop constraint if exists app_releases_backend_chk;

alter table public.app_releases
  add constraint app_releases_backend_chk
  check (backend in ('supabase', 'r2'));
