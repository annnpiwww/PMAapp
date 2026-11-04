-- ============================================================================
-- Migration: 2026-11-02-maintenance-logs-manado.sql
-- Deskripsi: Tabel log maintenance khusus KC Manado untuk sinkronisasi data
--            lintas teknisi dan visualisasi status maintenance pada Map Maintenance.
-- ============================================================================

create table if not exists public.maintenance_logs_manado (
  id text primary key,
  tanggal text not null,
  jam_selesai text,
  pos_id text not null,
  pos_name text not null,
  teknisi_nama text not null,
  teknisi_npp text default '',
  template_id text,
  template_name text default '',
  total_poin int default 0,
  sesuai_poin int default 0,
  temuan jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index untuk pencarian & filtering periode tanggal
create index if not exists idx_maintenance_logs_manado_tanggal
  on public.maintenance_logs_manado (tanggal);

-- Enable Row Level Security (RLS)
alter table public.maintenance_logs_manado enable row level security;

-- Policy: Allow all untuk anon, authenticated, dan service_role
drop policy if exists "Allow all on maintenance_logs_manado" on public.maintenance_logs_manado;
create policy "Allow all on maintenance_logs_manado"
  on public.maintenance_logs_manado
  for all
  to anon, authenticated, service_role
  using (true)
  with check (true);

-- Grant privileges
grant all on table public.maintenance_logs_manado to anon, authenticated, service_role;
