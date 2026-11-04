-- BssparkingTimeMark — lockdown keamanan Supabase
-- Tanggal: 2026-10-22
--
-- CARA PAKAI (manual di Supabase SQL Editor / CLI, BELUM diterapkan otomatis):
--   1. Backup dulu:  pg_dump / export dashboard.
--   2. Jalankan blok per bagian (A sampai D) supaya mudah di-rollback.
--   3. Test app: login SPV, create task, delete task pending, upload bukti.
--
-- RINGKASAN TEMUAN (bukti: probe read-only dengan anon key):
--   - SELECT app_users (anon)  -> 200, mengembalikan password PLAINTEXT semua akun.
--   - DELETE app_users (anon)  -> 204 (RLS mengizinkan delete).
--   - UPDATE app_users (anon)  -> 200 (RLS mengizinkan update).
--   - SELECT daily_tasks_bali   -> 200 (semua cabang bisa dibaca).
--   - LIST  task-proofs (anon)  -> 200 + unduh objek tanpa auth -> 200.
--  Arti: siapa pun yang punya APK (anon key bersifat publik) bisa baca
--   kredensial, menghapus data, dan mengambil foto bukti.

-- =========================================================
-- A. app_users: hentikan akses anon. Kolom 'password' plaintext WAJIB dihapus.
-- =========================================================
-- A1. Hapus kolom password plaintext (backup dulu!).
-- ALTER TABLE public.app_users DROP COLUMN IF EXISTS password;

-- A2. Matikan akses anon ke app_users.
--     Setelah ini, login harus lewat Edge Function 'auth-login' (server-side),
--     bukan SELECT langsung dari client.
-- REVOKE ALL ON public.app_users FROM anon, authenticated;

-- A3. Hapus policy lama yang membiarkan anon akses (nama policy bisa berbeda,
--     cek dulu: SELECT policyname, cmd, qual FROM pg_policies WHERE tablename='app_users';)
-- DROP POLICY IF EXISTS "Allow public read app_users" ON public.app_users;
-- DROP POLICY IF EXISTS "Allow public insert app_users" ON public.app_users;
-- DROP POLICY IF EXISTS "Allow public update app_users" ON public.app_users;
-- DROP POLICY IF EXISTS "Allow public delete app_users" ON public.app_users;

-- =========================================================
-- B. daily_tasks_*: hapus akses DELETE untuk anon.
--    SPV hapus tugas lewat Edge Function 'admin-delete-task' (server-side cek role).
-- =========================================================
-- REVOKE DELETE ON public.daily_tasks, public.daily_tasks_bali, public.daily_tasks_ho FROM anon;
-- REVOKE DELETE ON public.daily_tasks FROM authenticated;
-- (kalau policy SELECT/UPDATE juga longgar, tambahkan policy berbasis branch/role)

-- =========================================================
-- C. Bucket task-proofs: privat + signed URL.
--    Objek tidak lagi bisa diunduh tanpa header Authorization.
-- =========================================================
-- UPDATE storage.buckets SET public = false WHERE id = 'task-proofs';

-- Matikan policy publik lama (cek nama policy dulu).
-- DROP POLICY IF EXISTS "Public read task proofs" ON storage.objects;
-- DROP POLICY IF EXISTS "Allow public read" ON storage.objects;

-- =========================================================
-- D. Sanasi data lama yang sudah bocor (opsional tapi disarankan).
-- =========================================================
-- Pastikan tidak ada password plaintext yang tertinggal di log/backup lama.
-- UPDATE public.app_users SET password = NULL WHERE password IS NOT NULL;

-- =========================================================
-- E. Verifikasi setelah lockdown (harus TOLAK, bukan 200):
--   curl -i "$URL/rest/v1/app_users?select=*&limit=1"   -H "apikey: $ANON"
--   curl -i -X DELETE "$URL/rest/v1/daily_tasks_bali?id=eq.00000000-0000-0000-0000-000000000000" \
--        -H "apikey: $ANON" -H "Authorization: Bearer $ANON"
--   curl -i -X POST "$URL/storage/v1/object/list/task-proofs" -H "apikey: $ANON" \
--        -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" -d '{"prefix":""}'
-- =========================================================
