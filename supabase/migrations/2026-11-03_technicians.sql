-- Migration: Create public.technicians table, triggers, RLS, and seed data
-- Objective: Move per-branch technician names to Supabase

CREATE TABLE IF NOT EXISTS public.technicians (
  id uuid primary key default gen_random_uuid(),
  nama text not null check (char_length(nama) between 2 and 80),
  branch text not null check (branch in ('manado', 'bali', 'ho')),
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_technicians_lower_nama_branch ON public.technicians (lower(nama), branch);

-- Trigger bumping updated_at
CREATE OR REPLACE FUNCTION public.bump_technicians_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_technicians_updated_at ON public.technicians;
CREATE TRIGGER trg_technicians_updated_at
  BEFORE UPDATE ON public.technicians
  FOR EACH ROW
  EXECUTE FUNCTION public.bump_technicians_updated_at();

-- RLS: only SELECT active rows for anon and authenticated
ALTER TABLE public.technicians ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.technicians FROM anon, authenticated;
GRANT SELECT ON TABLE public.technicians TO anon, authenticated;
GRANT ALL ON TABLE public.technicians TO service_role;

DROP POLICY IF EXISTS "Allow select active technicians" ON public.technicians;
CREATE POLICY "Allow select active technicians"
  ON public.technicians
  FOR SELECT
  TO anon, authenticated
  USING (active = true);

-- Seed rows exactly matching BranchService.getTechnicians (lib/data/services/branch_service.dart:175-207)
INSERT INTO public.technicians (nama, branch, sort_order, active)
VALUES
  -- Bali (6 rows, sort_order 0-5)
  ('Putu Hyan Parta Wijaya', 'bali', 0, true),
  ('Alif Candra Triantoro', 'bali', 1, true),
  ('I Putu Indra Yohana', 'bali', 2, true),
  ('I PUTU GEDE SUARDANA PUTRA', 'bali', 3, true),
  ('ADITYA CAESAR BAGASKARA', 'bali', 4, true),
  ('ANAK AGUNG GEDE AGUNG YUSTIKAWANGSA', 'bali', 5, true),

  -- HO Makassar (10 rows, sort_order 0-9)
  ('AHMAD KHAELANI', 'ho', 0, true),
  ('HASRUL HAQ', 'ho', 1, true),
  ('MUH. HARDIN TAUFIK', 'ho', 2, true),
  ('FERDINAN PRADANA PANGALA PUTRA', 'ho', 3, true),
  ('ALIF AHMAD MAULANA', 'ho', 4, true),
  ('DANY RAMADHANI ASHARI', 'ho', 5, true),
  ('MUHAMMAD YUSUF SALAM', 'ho', 6, true),
  ('RAHMAD HIDAYAT', 'ho', 7, true),
  ('ARIF SURYA WIDODO', 'ho', 8, true),
  ('RIYAN ADNAN', 'ho', 9, true),

  -- Manado (4 rows, sort_order 0-3)
  ('Ryan Lumasuge', 'manado', 0, true),
  ('Raldy Sangkop', 'manado', 1, true),
  ('Junifer Manua', 'manado', 2, true),
  ('Alessandro Sulistyo', 'manado', 3, true)
ON CONFLICT DO NOTHING;
