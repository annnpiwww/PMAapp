-- Additive migration (safe for 2.0.132 apps in the field)
-- Adds PBKDF2 password hash column for server-side auth-login.

ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS password_hash text;
