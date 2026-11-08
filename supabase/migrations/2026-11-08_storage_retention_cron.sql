-- Migration: 2026-11-08_storage_retention_cron.sql
-- Enables pg_cron and pg_net extensions, registers vault secret placeholder,
-- and schedules daily storage retention Edge Function at 03:00 WITA (19:00 UTC).

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Note: The vault secret 'storage_retention_cron_secret' is provisioned via Supabase Vault:
-- select vault.create_secret('<CRON_SECRET_PLACEHOLDER>', 'storage_retention_cron_secret');

-- Unschedule existing job if present
do $$
begin
  if exists (select 1 from cron.job where jobname = 'storage-retention-daily') then
    perform cron.unschedule('storage-retention-daily');
  end if;
end $$;

-- Schedule daily retention cleanup at 19:00 UTC (03:00 WITA)
select cron.schedule(
  'storage-retention-daily',
  '0 19 * * *',
  $$
  select net.http_post(
    url := 'https://sxsjixnnlzhjinzcyhjb.supabase.co/functions/v1/storage-retention',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'storage_retention_cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
