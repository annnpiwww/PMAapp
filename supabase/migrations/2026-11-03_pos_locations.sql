-- Migration: Create public.pos_locations table, triggers, RLS, and seed data
-- Contract reference: docs/contracts/pos-locations.md

CREATE TABLE IF NOT EXISTS public.pos_locations (
  pos_id TEXT PRIMARY KEY CHECK (pos_id ~ '^[A-Za-z0-9_-]{3,60}$'),
  pos_name TEXT NOT NULL CHECK (length(pos_name) >= 1 AND length(pos_name) <= 120),
  cabang_name TEXT NOT NULL CHECK (length(cabang_name) >= 1 AND length(cabang_name) <= 120),
  full_address TEXT NOT NULL DEFAULT '' CHECK (length(full_address) <= 300),
  location_tag TEXT NOT NULL CHECK (length(location_tag) >= 1 AND length(location_tag) <= 16 AND location_tag = upper(location_tag)),
  tag_color BIGINT NOT NULL DEFAULT 4294286859,
  branch TEXT NOT NULL CHECK (branch IN ('manado', 'bali', 'ho')),
  lat DOUBLE PRECISION NOT NULL CHECK (lat >= -90 AND lat <= 90),
  lng DOUBLE PRECISION NOT NULL CHECK (lng >= -180 AND lng <= 180),
  active BOOLEAN NOT NULL DEFAULT true,
  source TEXT NOT NULL DEFAULT 'seed' CHECK (source IN ('seed', 'spv', 'device_import')),
  updated_by TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger bumping updated_at
CREATE OR REPLACE FUNCTION public.bump_pos_locations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pos_locations_updated_at ON public.pos_locations;
CREATE TRIGGER trg_pos_locations_updated_at
  BEFORE UPDATE ON public.pos_locations
  FOR EACH ROW
  EXECUTE FUNCTION public.bump_pos_locations_updated_at();

-- RLS: only SELECT active rows for anon and authenticated
ALTER TABLE public.pos_locations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.pos_locations FROM anon, authenticated;
GRANT SELECT ON TABLE public.pos_locations TO anon, authenticated;
GRANT ALL ON TABLE public.pos_locations TO service_role;

DROP POLICY IF EXISTS "Allow select active pos_locations" ON public.pos_locations;
CREATE POLICY "Allow select active pos_locations"
  ON public.pos_locations
  FOR SELECT
  TO anon, authenticated
  USING (active = true);

-- Seed rows from LocationService._defaultSeed
INSERT INTO public.pos_locations (
  pos_id, pos_name, cabang_name, full_address, location_tag, tag_color, branch, lat, lng, active, source
) VALUES
  ('POS-PBM-01', 'Pasar Bersehati Manado', 'KC BSG', 'Jl. Nusantara No.17, Calaca, Wenang, Kota Manado, Sulawesi Utara', 'PBM', 4294286859, 'manado', 1.4980709, 124.8415709, true, 'seed'),
  ('POS-PKM-01', 'Pelabuhan Kalimas Manado', 'KC BSG', 'Jl. Rumambi, Calaca, Wenang, Kota Manado, Sulawesi Utara', 'PKM', 4294286859, 'manado', 1.4986164, 124.8400064, true, 'seed'),
  ('POS-MPP-01', 'Mall Pelayanan Publik', 'KC BSG', 'Jl. Piere Tendean, Sario Tumpaan, Sario, Kota Manado, Sulawesi Utara 95114', 'MPP', 4294286859, 'manado', 1.4689489, 124.8303596, true, 'seed'),
  ('POS-NBM-01', 'New Bendar Manado', 'KC BSG', 'President Shopping Center, Jl. Walanda Maramis, Pinaesaan, Wenang, Kota Manado, Sulawesi Utara', 'NBM', 4294286859, 'manado', 1.4934467, 124.8416130, true, 'seed'),
  ('POS-PPM-01', 'Pasar Pinasungkulan Manado', 'KC BSG', 'Jl. Pasar Karombasan, Karombasan Utara, Wanea, Kota Manado, Sulawesi Utara', 'PPM', 4294286859, 'manado', 1.4567512, 124.8402042, true, 'seed'),
  ('POS-TBM-01', 'Toko Bintang Manado', 'KC BSG', 'Jl. A.A. Maramis No.291, Paniki Bawah, Kec. Mapanget, Kota Manado, Sulawesi Utara', 'TBM', 4294286859, 'manado', 1.5030, 124.9000, true, 'seed'),
  ('POS-MGAM-01', 'Mie Gacoan AA Maramis', 'KC BSG', 'Jl. A.A. Maramis, Paniki Bawah, Kec. Mapanget, Kota Manado, Sulawesi Utara', 'MGAM', 4294286859, 'manado', 1.5059531, 124.9033492, true, 'seed'),
  ('POS-MGMM-01', 'Mie Gacoan AirMadidi', 'KC BSG', 'CXCP+V34, Airmadidi Atas, Kec. Airmadidi, Kabupaten Minahasa Utara, Sulawesi Utara', 'MGMM', 4294286859, 'manado', 1.4221375, 124.9852031, true, 'seed'),
  ('POS-MGBP-01', 'Mie Gacoan Babe Palar', 'KC BSG', 'Jl. Babe Palar No.81, Madidir Ure, Kec. Maesa, Kota Bitung, Sulawesi Utara', 'MGBP', 4294286859, 'manado', 1.4429952, 125.1583095, true, 'seed'),
  ('POS-MGTO-01', 'Mie Gacoan Tomohon', 'KC BSG', 'Jl. Raya Tomohon, Talete Satu, Kec. Tomohon Tengah, Kota Tomohon, Sulawesi Utara', 'MGTO', 4294286859, 'manado', 1.3285085, 124.8396419, true, 'seed'),
  ('POS-MGKB-01', 'Mie Gacoan Kotamobagu', 'KC BSG', 'P7JX+JXX, Molinow, Kec. Kotamobagu Barat, Kota Kotamobagu, Sulawesi Utara', 'MGKB', 4294286859, 'manado', 0.7316125, 124.2999844, true, 'seed'),
  ('POS-MGNW-01', 'Mie Gacoan Nani Wartabone', 'KC BSG', 'Jl. Nani Wartabone No.05, Heledulaa Selatan, Kec. Kota Timur, Kota Gorontalo, Gorontalo', 'MGNW', 4294286859, 'manado', 0.5397008, 123.0610370, true, 'seed'),
  ('POS-MGGJ-01', 'Mie Gacoan Gorontalo Jhon', 'KC BSG', 'H3C4+FX9, Tapa, Kec. Sipatana, Kota Gorontalo, Gorontalo', 'MGGJ', 4294286859, 'manado', 0.5711625, 123.0574844, true, 'seed'),
  ('POS-MGLG-01', 'Mie Gacoan Limboto Gorontalo', 'KC BSG', 'JXCG+6M2, Jl. Jenderal Sudirman, Hunggaluwa, Kec. Limboto, Kabupaten Gorontalo, Gorontalo', 'MGLG', 4294286859, 'manado', 0.6205125, 122.9766406, true, 'seed'),
  ('POS-DPS-PBKD', 'PBKD', 'KC Bali', 'Pos Pengelolaan PBKD, KC Bali', 'PBKD', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-PCD', 'PCD', 'KC Bali', 'Pos Pengelolaan PCD, KC Bali', 'PCD', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-PKRD', 'PKRD', 'KC Bali', 'Pos Pengelolaan PKRD, KC Bali', 'PKRD', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-PAS', 'PAS', 'KC Bali', 'Pos Pengelolaan PAS, KC Bali', 'PAS', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-PSD', 'PSD', 'KC Bali', 'Pos Pengelolaan PSD, KC Bali', 'PSD', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-PGA', 'PGA', 'KC Bali', 'Pos Pengelolaan PGA, KC Bali', 'PGA', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-TBB', 'TBB', 'KC Bali', 'Pos Pengelolaan TBB, KC Bali', 'TBB', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-TBG', 'TBG', 'KC Bali', 'Pos Pengelolaan TBG, KC Bali', 'TBG', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-KIH', 'KIH', 'KC Bali', 'Pos Pengelolaan KIH, KC Bali', 'KIH', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-BMS', 'BMS', 'KC Bali', 'Pos Pengelolaan BMS, KC Bali', 'BMS', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-BMK', 'BMK', 'KC Bali', 'Pos Pengelolaan BMK, KC Bali', 'BMK', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-SPD', 'SPD', 'KC Bali', 'Pos Pengelolaan SPD, KC Bali', 'SPD', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-GYS', 'GYS', 'KC Bali', 'Pos Pengelolaan GYS, KC Bali', 'GYS', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-PBB', 'PBB', 'KC Bali', 'Pos Pengelolaan PBB, KC Bali', 'PBB', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-DPS-RSPM', 'RSPM', 'KC Bali', 'Pos Pengelolaan RSPM, KC Bali', 'RSPM', 4294286859, 'bali', -8.670458, 115.212629, true, 'seed'),
  ('POS-HO-TBP-01', 'Toko Bintang Palangga', 'HO Makassar', 'Toko Bintang Palangga, HO Makassar', 'TBP', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-GMM-01', 'Grand Mall Maros', 'HO Makassar', 'Grand Mall Maros, HO Makassar', 'GMM', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-RSWS-01', 'Rumah Sakit Wahidin Sudirohusodo', 'HO Makassar', 'Rumah Sakit Wahidin Sudirohusodo, HO Makassar', 'RSWS', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-MGPO-01', 'MG Polman', 'HO Makassar', 'MG Polman, HO Makassar', 'MGPO', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-MGPI-01', 'MG Pinrang', 'HO Makassar', 'MG Pinrang, HO Makassar', 'MGPI', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-MGWJ-01', 'MG Wajo', 'HO Makassar', 'MG Wajo, HO Makassar', 'MGWJ', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-PCC-01', 'Private Care Centre', 'HO Makassar', 'Private Care Centre, HO Makassar', 'PCC', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-MGPP-01', 'MG Pepaya Bone', 'HO Makassar', 'MG Pepaya Bone, HO Makassar', 'MGPP', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-MGSP-01', 'MG Sidrap', 'HO Makassar', 'MG Sidrap, HO Makassar', 'MGSP', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-MGKW-01', 'MG Kendari', 'HO Makassar', 'MG Kendari, HO Makassar', 'MGKW', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-KMS-01', 'Karsa Mini Soccer', 'HO Makassar', 'Karsa Mini Soccer, HO Makassar', 'KMS', 4294286859, 'ho', 0, 0, true, 'seed'),
  ('POS-HO-PJT-01', 'Pusat Jantung Terpadu', 'HO Makassar', 'Pusat Jantung Terpadu, HO Makassar', 'PJT', 4294286859, 'ho', 0, 0, true, 'seed')
ON CONFLICT (pos_id) DO NOTHING;
