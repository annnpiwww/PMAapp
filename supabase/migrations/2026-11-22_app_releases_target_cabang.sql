-- Migration: 2026-11-22_app_releases_target_cabang.sql
-- PMApp per-branch staged rollout: add nullable target_cabang allowlist array.

alter table public.app_releases
  add column if not exists target_cabang text[] null;

alter table public.app_releases
  drop constraint if exists app_releases_target_cabang_chk;

alter table public.app_releases
  add constraint app_releases_target_cabang_chk
  check (
    target_cabang is null
    or (
      cardinality(target_cabang) >= 1
      and target_cabang <@ array['manado','bali','ho']::text[]
    )
  );
