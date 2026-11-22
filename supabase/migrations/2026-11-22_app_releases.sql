-- Migration: 2026-11-22_app_releases.sql
-- PMApp P1 in-app updater: app_releases metadata table + private app-releases storage bucket.

create table if not exists public.app_releases (
  id uuid primary key default gen_random_uuid(),
  app text not null default 'pmapp' check (app = 'pmapp'),
  abi text not null check (abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64')),
  version_code int not null check (version_code > 0),
  base_version_code int not null check (base_version_code > 0),
  version_name text not null check (version_name ~ '^[0-9]+\.[0-9]+\.[0-9]+$'),
  apk_path text null,
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 52428800),
  changelog text not null default '',
  mandatory boolean not null default false,
  min_supported_version text null check (
    min_supported_version is null
    or min_supported_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$'
  ),
  status text not null default 'draft' check (
    status in ('draft', 'published', 'rolled_back', 'archived')
  ),
  created_by text not null,
  created_at timestamptz not null default now(),
  published_at timestamptz null,
  unique (app, abi, version_code),
  check (
    version_code = base_version_code + case abi
      when 'armeabi-v7a' then 1000
      when 'arm64-v8a' then 2000
      else 4000
    end
  )
);

create index if not exists idx_app_releases_lookup
  on public.app_releases (app, abi, status, version_code desc);

-- All reads/writes go through the service_role Edge Function; zero anon/authenticated access.
alter table public.app_releases enable row level security;
revoke all on table public.app_releases from anon, authenticated;
grant all on table public.app_releases to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-releases',
  'app-releases',
  false,
  52428800,
  array['application/vnd.android.package-archive', 'application/octet-stream']
)
on conflict (id) do nothing;
