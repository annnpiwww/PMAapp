-- ============================================================
-- Tabel tugas harian cabang HO Makassar (19 Oktober 2026)
-- ============================================================
-- Aplikasi memilih tabel dari cabang aktif (lihat DailyTaskService.tasksTable):
--   KC Manado   -> public.daily_tasks_manado
--   KC Bali     -> public.daily_tasks_bali
--   HO Makassar -> public.daily_tasks_ho   <-- file ini
--
-- Jalankan sekali di Supabase SQL Editor sebelum cabang HO dipakai SPV.
-- Tanpa tabel ini, tugas harian HO akan gagal disimpan (tabel tidak ditemukan).
-- Tabel cabang lain tidak diubah.

-- 1) Tabel tugas harian HO (skema identik daily_tasks_manado / daily_tasks_bali)
create table if not exists public.daily_tasks_ho (
  id text not null primary key,
  tanggal text not null,
  teknisi_id text default '',
  teknisi_nama text not null,
  pos_name text not null,
  pos_tag text not null,
  judul text not null,
  deskripsi text default '',
  kategori text default 'khusus',
  template_id text,
  status text default 'pending',
  jam_selesai text,
  foto_bukti jsonb default '[]'::jsonb,
  catatan_teknisi text,
  peserta text default '',
  serah_terima text default '',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 2) Jaring anti duplikat harian
create unique index if not exists daily_tasks_ho_unique_per_day
  on public.daily_tasks_ho (tanggal, teknisi_nama, judul, pos_tag);

-- 3) Akses aplikasi (anon key) + service role, meniru policy tabel cabang lain
alter table public.daily_tasks_ho enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'daily_tasks_ho') then
    create policy "Allow all" on public.daily_tasks_ho
      for all to anon, authenticated, service_role using (true) with check (true);
  end if;
end $$;

grant all on public.daily_tasks_ho to anon, authenticated, service_role;
