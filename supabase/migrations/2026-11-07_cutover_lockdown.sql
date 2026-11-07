-- Apply together with: supabase secrets set ENFORCE_SESSION=true
-- Cutover lockdown migration (WRITE ONLY — DO NOT APPLY until all field apps are updated)
-- Closes SEC-04 (direct app_users access + plaintext passwords) and SEC-05 (anon INSERT/DELETE/assignment tamper on daily_tasks_*).

-- 1. Lock down public.app_users completely from client Data API roles (login runs via auth-login service_role)
REVOKE ALL ON TABLE public.app_users FROM anon, authenticated;

-- 2. Clear plaintext passwords for every account already migrated to PBKDF2 password_hash
UPDATE public.app_users
SET password = NULL
WHERE password_hash IS NOT NULL;

-- 3. Guard anon updates on daily_tasks_manado, daily_tasks_bali, daily_tasks_ho:
--    - Forbid modifying already-completed rows.
--    - Forbid changing immutable task/creator/assignment/location columns.
CREATE OR REPLACE FUNCTION public.guard_anon_daily_tasks_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF lower(coalesce(OLD.status, '')) IN ('completed', 'selesai', 'done', 'finish', 'finished', 'sukses', 'closed') THEN
      RAISE EXCEPTION 'completed task is immutable' USING ERRCODE = '42501';
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id
      OR NEW.tanggal IS DISTINCT FROM OLD.tanggal
      OR NEW.teknisi_id IS DISTINCT FROM OLD.teknisi_id
      OR NEW.teknisi_nama IS DISTINCT FROM OLD.teknisi_nama
      OR NEW.peserta IS DISTINCT FROM OLD.peserta
      OR NEW.pos_name IS DISTINCT FROM OLD.pos_name
      OR NEW.pos_tag IS DISTINCT FROM OLD.pos_tag
      OR NEW.judul IS DISTINCT FROM OLD.judul
      OR NEW.deskripsi IS DISTINCT FROM OLD.deskripsi
      OR NEW.kategori IS DISTINCT FROM OLD.kategori
      OR NEW.template_id IS DISTINCT FROM OLD.template_id
      OR NEW.created_at IS DISTINCT FROM OLD.created_at
    THEN
      RAISE EXCEPTION 'immutable task assignment columns cannot be changed by client' USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Apply table-level privilege revocations, narrow RLS policies, and BEFORE UPDATE triggers across all 3 branch tables
DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['daily_tasks_manado', 'daily_tasks_bali', 'daily_tasks_ho']
  LOOP
    EXECUTE format('REVOKE INSERT, DELETE, TRUNCATE ON TABLE public.%I FROM anon, authenticated', tbl);
    EXECUTE format('GRANT SELECT, UPDATE ON TABLE public.%I TO anon, authenticated', tbl);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role', tbl);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);

    EXECUTE format('DROP POLICY IF EXISTS "Allow all" ON public.%I', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "anon_select_daily_tasks" ON public.%I', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "anon_update_daily_tasks" ON public.%I', tbl);
    EXECUTE format('DROP POLICY IF EXISTS "service_role_all_daily_tasks" ON public.%I', tbl);

    EXECUTE format(
      'CREATE POLICY "anon_select_daily_tasks" ON public.%I FOR SELECT TO anon, authenticated USING (true)',
      tbl
    );
    EXECUTE format(
      'CREATE POLICY "anon_update_daily_tasks" ON public.%I FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true)',
      tbl
    );
    EXECUTE format(
      'CREATE POLICY "service_role_all_daily_tasks" ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)',
      tbl
    );

    EXECUTE format('DROP TRIGGER IF EXISTS trg_guard_anon_daily_tasks_update ON public.%I', tbl);
    EXECUTE format(
      'CREATE TRIGGER trg_guard_anon_daily_tasks_update BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.guard_anon_daily_tasks_update()',
      tbl
    );
  END LOOP;
END;
$$;

-- ============================================================================
-- ROLLBACK (uncomment and execute manually only if emergency rollback is needed)
-- Note: Plaintext app_users.password values cleared above cannot be recovered
-- from PBKDF2 hashes; reset individual passwords via service_role if needed.
-- ============================================================================
-- GRANT SELECT ON TABLE public.app_users TO anon, authenticated;
--
-- DO $$
-- DECLARE
--   tbl text;
-- BEGIN
--   FOREACH tbl IN ARRAY ARRAY['daily_tasks_manado', 'daily_tasks_bali', 'daily_tasks_ho']
--   LOOP
--     EXECUTE format('DROP TRIGGER IF EXISTS trg_guard_anon_daily_tasks_update ON public.%I', tbl);
--     EXECUTE format('DROP POLICY IF EXISTS "anon_select_daily_tasks" ON public.%I', tbl);
--     EXECUTE format('DROP POLICY IF EXISTS "anon_update_daily_tasks" ON public.%I', tbl);
--     EXECUTE format('DROP POLICY IF EXISTS "service_role_all_daily_tasks" ON public.%I', tbl);
--     EXECUTE format('CREATE POLICY "Allow all" ON public.%I FOR ALL USING (true) WITH CHECK (true)', tbl);
--     EXECUTE format('GRANT ALL ON TABLE public.%I TO anon, authenticated, service_role', tbl);
--   END LOOP;
-- END;
-- $$;
--
-- DROP FUNCTION IF EXISTS public.guard_anon_daily_tasks_update();
