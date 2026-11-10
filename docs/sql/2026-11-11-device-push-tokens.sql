-- Migration: 2026-11-11_device_push_tokens.sql
-- Device push tokens for Firebase Cloud Messaging (FCM) & DB triggers for error tickets.

-- 1. Table public.device_push_tokens
create table if not exists public.device_push_tokens (
    token text primary key,
    user_name text not null,
    cabang text not null,
    role text not null,
    platform text not null default 'android',
    updated_at timestamptz not null default now()
);

-- Enable RLS (Service role only; no anon/authenticated policies)
alter table public.device_push_tokens enable row level security;
grant all on public.device_push_tokens to service_role;

-- Index on cabang & user_name for fast lookup in error-push
create index if not exists idx_device_push_tokens_cabang on public.device_push_tokens(cabang);
create index if not exists idx_device_push_tokens_user_name on public.device_push_tokens(user_name);

-- 2. Vault secret for error-push edge function authentication
do $$
declare
  v_existing uuid;
  v_new_secret text;
begin
  select id into v_existing from vault.secrets where name = 'error_push_shared_secret' limit 1;
  if v_existing is null then
    v_new_secret := encode(gen_random_bytes(32), 'hex');
    perform vault.create_secret(v_new_secret, 'error_push_shared_secret', 'Shared secret for error-push edge function triggered from database');
  end if;
end;
$$;

-- 3. Trigger function to invoke error-push via pg_net
create or replace function public.trigger_error_push_notify()
returns trigger
language plpgsql
security definer
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'error_push_shared_secret'
  limit 1;

  if v_secret is not null and length(v_secret) > 0 then
    perform net.http_post(
      url := 'https://sxsjixnnlzhjinzcyhjb.supabase.co/functions/v1/error-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-error-push-secret', v_secret
      ),
      body := jsonb_build_object(
        'table', TG_TABLE_NAME,
        'record', row_to_json(NEW)
      )
    );
  end if;

  return NEW;
end;
$$;

-- 4. Triggers on daily_tasks_manado, daily_tasks_bali, daily_tasks_ho
drop trigger if exists on_error_ticket_inserted_manado on public.daily_tasks_manado;
create trigger on_error_ticket_inserted_manado
  after insert on public.daily_tasks_manado
  for each row
  when (NEW.kategori = 'error' and NEW.status = 'pending')
  execute function public.trigger_error_push_notify();

drop trigger if exists on_error_ticket_inserted_bali on public.daily_tasks_bali;
create trigger on_error_ticket_inserted_bali
  after insert on public.daily_tasks_bali
  for each row
  when (NEW.kategori = 'error' and NEW.status = 'pending')
  execute function public.trigger_error_push_notify();

drop trigger if exists on_error_ticket_inserted_ho on public.daily_tasks_ho;
create trigger on_error_ticket_inserted_ho
  after insert on public.daily_tasks_ho
  for each row
  when (NEW.kategori = 'error' and NEW.status = 'pending')
  execute function public.trigger_error_push_notify();
