-- ============================================================
-- Pemisahan tabel tugas harian per cabang (18 Oktober 2026)
-- ============================================================
-- Aplikasi kini memilih tabel dari cabang aktif:
--   KC Manado -> public.daily_tasks_manado
--   KC Bali   -> public.daily_tasks_bali
-- Tabel lama public.daily_tasks tidak dihapus, disimpan sebagai arsip.
--
-- Catatan: untuk cabang baru, ulangi blok 1 dengan tabel
-- `daily_tasks_<slug cabang>` (lihat DailyTaskService.tasksTable).

-- 1) Kolom baru yang dipakai fitur teknisi tambahan & serah terima shift
alter table public.daily_tasks add column if not exists peserta text default '';
alter table public.daily_tasks add column if not exists serah_terima text default '';

create table if not exists public.daily_tasks_manado (
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

create table if not exists public.daily_tasks_bali (
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

-- 2) Jaring anti duplikat harian, sama seperti tabel lama
create unique index if not exists daily_tasks_manado_unique_per_day
  on public.daily_tasks_manado (tanggal, teknisi_nama, judul, pos_tag);
create unique index if not exists daily_tasks_bali_unique_per_day
  on public.daily_tasks_bali (tanggal, teknisi_nama, judul, pos_tag);

-- 3) Akses aplikasi (anon key) + service role, meniru policy tabel lama
alter table public.daily_tasks_manado enable row level security;
alter table public.daily_tasks_bali enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'daily_tasks_manado') then
    create policy "Allow all" on public.daily_tasks_manado
      for all to anon, authenticated, service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'daily_tasks_bali') then
    create policy "Allow all" on public.daily_tasks_bali
      for all to anon, authenticated, service_role using (true) with check (true);
  end if;
end $$;

grant all on public.daily_tasks_manado to anon, authenticated, service_role;
grant all on public.daily_tasks_bali to anon, authenticated, service_role;

-- 4) Salin riwayat dari tabel lama (sekali jalan).
--    Semua 11 baris lama milik teknisi Manado; baris yang namanya tidak
--    dikenali tetap tinggal di public.daily_tasks sebagai arsip.
insert into public.daily_tasks_manado
  (id, tanggal, teknisi_id, teknisi_nama, pos_name, pos_tag, judul, deskripsi, kategori,
   template_id, status, jam_selesai, foto_bukti, catatan_teknisi, created_at, updated_at)
select id, tanggal, teknisi_id, teknisi_nama, pos_name, pos_tag, judul, deskripsi, kategori,
       template_id, status, jam_selesai, foto_bukti, catatan_teknisi, created_at, updated_at
from public.daily_tasks
where lower(teknisi_nama) in ('ryan lumasuge', 'raldy sangkop', 'junifer manua', 'alessandro sulistyo')
on conflict (id) do nothing;
