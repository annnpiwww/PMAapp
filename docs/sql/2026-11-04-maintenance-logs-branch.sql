-- ============================================================================
-- Migration: 2026-11-04-maintenance-logs-branch.sql
-- Deskripsi: Menambahkan kolom branch pada tabel maintenance_logs_manado agar
--            tabel ini dapat menyimpan log maintenance untuk seluruh cabang
--            (KC Manado = 'MDO', KC Bali = 'DPS', HO Makassar = 'HO').
-- ============================================================================

-- Tambahkan kolom branch dengan default 'MDO' (kompatibel dengan versi lama)
alter table public.maintenance_logs_manado
  add column if not exists branch text not null default 'MDO';

-- Index untuk filter branch & tanggal pada Map Maintenance & sinkronisasi
create index if not exists idx_maintenance_logs_branch_tanggal
  on public.maintenance_logs_manado (branch, tanggal);

comment on table public.maintenance_logs_manado is
  'Tabel log maintenance terpusat untuk semua cabang (MDO, DPS, HO).';
