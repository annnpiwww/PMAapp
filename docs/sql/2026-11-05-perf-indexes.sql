-- ============================================================================
-- Performance indexes (2026-11-05 audit, section "Ready-to-Run Index SQL")
-- Jalankan sekali di Supabase SQL Editor. Aman dijalankan ulang (idempotent).
-- Sengaja TIDAK memakai CONCURRENTLY: file ini dijalankan manual, bukan migrasi.
-- Index app_users(lower(...)) tidak dipakai karena login memakai ilike PostgREST.
-- ============================================================================

-- 1. Daily Tasks: polling 25 detik (status = pending, order created_at desc)
CREATE INDEX IF NOT EXISTS idx_daily_tasks_manado_status_created
  ON public.daily_tasks_manado (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_bali_status_created
  ON public.daily_tasks_bali (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_ho_status_created
  ON public.daily_tasks_ho (status, created_at DESC);

-- 2. Daily Tasks: scoping tugas per teknisi
CREATE INDEX IF NOT EXISTS idx_daily_tasks_manado_teknisi_status
  ON public.daily_tasks_manado (teknisi_nama, status, tanggal);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_bali_teknisi_status
  ON public.daily_tasks_bali (teknisi_nama, status, tanggal);

CREATE INDEX IF NOT EXISTS idx_daily_tasks_ho_teknisi_status
  ON public.daily_tasks_ho (teknisi_nama, status, tanggal);

-- 3. POS Locations: filter active + branch
CREATE INDEX IF NOT EXISTS idx_pos_locations_active_branch
  ON public.pos_locations (active, branch);

-- 4. Technicians: daftar aktif terurut untuk BranchService sync
CREATE INDEX IF NOT EXISTS idx_technicians_active_branch_sort
  ON public.technicians (active, branch, sort_order);

-- 5. Maintenance Logs: index-only scan untuk map bulanan
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_branch_tanggal_jam
  ON public.maintenance_logs_manado (branch, tanggal DESC, jam_selesai DESC);

CREATE INDEX IF NOT EXISTS idx_maintenance_logs_pos_id
  ON public.maintenance_logs_manado (pos_id);
