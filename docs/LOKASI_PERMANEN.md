# 📍 Daftar Lokasi Permanen BSS Parking (KC BSG)

Daftar lokasi pos parkir dan unit operasional yang tersimpan secara permanen pada aplikasi **BSS Parking TimeMark**.

---

## 📋 Tabel Referensi Lokasi & Tag Card

| No | Nama Lokasi | Tag Card | Cabang / Area | Pos ID | Wilayah |
|:---:|:---|:---:|:---:|:---:|:---|
| 1 | **Pasar Bersehati Manado** | `PBM` | KC BSG | `POS-PBM-01` | Kota Manado, Sulawesi Utara |
| 2 | **Pelabuhan Kalimas Manado** | `PKM` | KC BSG | `POS-PKM-01` | Kota Manado, Sulawesi Utara |
| 3 | **Mall Pelayanan Publik** | `MPP` | KC BSG | `POS-MPP-01` | Kota Manado, Sulawesi Utara |
| 4 | **New Bendar Manado** | `NBM` | KC BSG | `POS-NBM-01` | Kota Manado, Sulawesi Utara |
| 5 | **Pasar Pinasungkulan Manado** | `PPM` | KC BSG | `POS-PPM-01` | Kota Manado, Sulawesi Utara |
| 6 | **Toko Bintang Manado** | `TBM` | KC BSG | `POS-TBM-01` | Kota Manado, Sulawesi Utara |
| 7 | **Mie Gacoan AA Maramis** | `MGAM` | KC BSG | `POS-MGAM-01` | Kota Manado, Sulawesi Utara |
| 8 | **Mie Gacoan AirMadidi** | `MGMM` | KC BSG | `POS-MGMM-01` | Minahasa Utara, Sulawesi Utara |
| 9 | **Mie Gacoan Babe Palar** | `MGBP` | KC BSG | `POS-MGBP-01` | Kota Manado, Sulawesi Utara |
| 10 | **Mie Gacoan Tomohon** | `MGTO` | KC BSG | `POS-MGTO-01` | Kota Tomohon, Sulawesi Utara |
| 11 | **Mie Gacoan Kotamobagu** | `MGKB` | KC BSG | `POS-MGKB-01` | Kota Kotamobagu, Sulawesi Utara |
| 12 | **Mie Gacoan Nani Wartabone** | `MGNW` | KC BSG | `POS-MGNW-01` | Kota Gorontalo, Gorontalo |
| 13 | **Mie Gacoan Gorontalo Jhon** | `MGGJ` | KC BSG | `POS-MGGJ-01` | Kota Gorontalo, Gorontalo |
| 14 | **Mie Gacoan Limboto Gorontalo** | `MGLG` | KC BSG | `POS-MGLG-01` | Kab. Gorontalo, Gorontalo |

---

## 🏷️ Format Integrasi Watermark & Laporan

1. **Watermark Card**: Menampilkan Tag Card unik pada pojok kartu watermark foto (contoh: `[PBM]`, `[PKM]`, `[MGAM]`).
2. **Laporan WhatsApp & Telegram**:
   - Secara otomatis menyertakan tag lokasi dalam format resmi:
     `Lokasi : Pelabuhan Kalimas Manado (PKM)`
     `Lokasi : Mie Gacoan AA Maramis (MGAM)`
3. **Penyimpanan Lokal (Offline Resilience)**:
   - Lokasi-lokasi ini di-seed secara otomatis ke dalam `LocationService._defaultSeed` dan disinkronkan ke penyimpanan lokal (`SharedPreferences`).
   - Perangkat yang sudah terinstal sebelumnya akan otomatis menggabungkan (merge) lokasi baru ini tanpa perlu hapus data aplikasi.
