# BssparkingTimeMark — Audit Report & Application Flow

> **Aplikasi**: BSS Parking Timemark · **Stack**: Flutter 3.11+ (Dart) · **Target**: Android/iOS
> **Tujuan**: Kamera internal anti-manipulasi untuk petugas lapangan BSS Parking — foto + watermark waktu/GPS + verifikasi SOP via AI Vision.

---

## 1. Ringkasan Singkat

| Aspek | Detail |
|---|---|
| **Platform** | Flutter mobile (Android, iOS) — Material 3, Google Fonts (Plus Jakarta Sans) |
| **Entry point** | `main.dart` → `BssParkingTimemarkApp` → `CameraCaptureScreen` (home) |
| **State Mgmt** | `ChangeNotifier` singleton repos + `setState` + listener (no Riverpod/BLoC) |
| **Persistence** | `SharedPreferences` JSON (7 keys) — MVP, no DB |
| **Backend** | Tidak ada — app berdiri sendiri, HTTP call ke Omniroute AI Vision API |
| **Auth** | Mock login (3 akun demo hardcoded) — tidak ada password hashing |
| **Asset** | `foto/images.jpeg` (logo drawer) |
| **Versi** | 1.0.0+1 (Dart SDK ^3.11.5) |

---

## 2. Tech Stack & Dependencies

| Package | Versi | Fungsi |
|---|---|---|
| `camera` | ^0.11.0+1 | Live preview + native capture |
| `image_picker` | ^1.1.2 | Logo picker dari galeri (modal) |
| `geolocator` | ^13.0.2 | GPS device real-time |
| `geocoding` | ^3.0.0 | Reverse-geocode lat/lng → alamat |
| `image` | ^4.9.2 | Watermark burn ke file (canvas/PNG) |
| `gal` | ^2.3.1 | Save foto ke gallery "BSS Parking" |
| `share_plus` | ^10.1.4 | Share ke Telegram/other apps |
| `url_launcher` | ^6.3.1 | Deep link Telegram |
| `shared_preferences` | ^2.3.2 | KV store |
| `http` | ^1.6.0 | HTTP client ke AI Vision API |
| `crypto` | ^3.0.6 | SHA-256 hash → kode verifikasi |
| `uuid` | ^4.5.1 | ID generator (template/pos) |
| `google_fonts` | ^6.2.1 | Typography |
| `intl` | ^0.19.0 | Date formatting (WIB/WITA) |
| `cupertino_icons` | ^1.0.8 | iOS icons |
| **dev** `flutter_lints` | ^6.0.0 | Lint rules |

---

## 3. Struktur Direktori

```
lib/
├── main.dart                              # Init repos + runApp
├── core/
│   ├── constants/
│   │   ├── app_colors.dart                # Palet Material 3 + BSS brand
│   │   └── app_theme.dart                 # ThemeData (light M3)
│   └── utils/
│       ├── image_watermark_processor.dart # Burn watermark ke file PNG
│       ├── share_helper.dart              # Save galeri + share Telegram
│       ├── timemark_formatter.dart        # Format tanggal/jam/GPS Indonesia
│       ├── verification_code.dart         # SHA-256 → BSS-XXXXXXXX
│       └── watermark_painter.dart         # Widget live + static watermark
├── data/
│   ├── models/                            # UserModel, TemplateModel, SubmissionModel, dll
│   ├── repositories/                      # Auth, Submission, Template (singleton)
│   └── services/                          # Storage, Location, AI Vision
└── features/
    ├── auth/screens/login_screen.dart
    ├── camera/screens/camera_capture_screen.dart        # ⭐ Main screen
    ├── camera/widgets/sop_verification_modal.dart       # Bottom sheet hasil AI
    ├── camera/widgets/watermark_customizer_modal.dart   # Customize watermark
    ├── history/screens/history_list_screen.dart
    ├── history/screens/history_detail_screen.dart
    ├── home/screens/main_shell_screen.dart              # 4-tab nav
    ├── locations/screens/location_management_screen.dart
    ├── locations/widgets/location_picker_modal.dart
    ├── profile/screens/profile_screen.dart
    ├── settings/screens/ai_vision_settings_screen.dart
    └── templates/screens/
        ├── template_list_screen.dart
        ├── template_editor_screen.dart
        └── card_template_management_screen.dart
```

---

## 4. Fitur Lengkap (Detail)

### 4.1 Autentikasi & Role
- **Login** (`login_screen.dart`): Pilih 1 dari 3 akun demo (Petugas Rian / Supervisor Santi / HO Boy), pilih pos/cabang, klik Masuk. Email auto-fill saat pilih user.
- **Role** (`UserRole`): `petugas` / `supervisor` / `ho` — berbeda icon di badge.
- **Pos switcher** di Profile: ganti pos/cabang aktif kapan saja.
- **Demo account switch**: uji coba semua role dari Profile screen.
- **Logout**: clear session → kembali ke LoginScreen.
- ⚠️ Tidak ada password validation — pure demo.

### 4.2 Kamera Timemark (Fitur Inti)
- **Live preview** pakai `package:camera` (720p/1080p).
- **Flash modes**: off → auto → always → off (cycle).
- **Zoom**: chip 1x/2x/5x + `setZoomLevel` (1.0–max).
- **Front/back flip**: tap icon.
- **Lifecycle**: dispose/re-init on `inactive`/`resumed` (permission dialog flow).
- **Auto-capture flow**:
 1. Generate `kodeVerifikasi` (SHA-256 dari timestamp+lat+lng+userId+salt → `BSS-XXXXXXXX`).
 2. `takePicture()` → file path.
 3. Burn watermark ke file (async, fire-and-forget).
 4. Kirim base64 thumbnail ke AI Vision.
 5. Tampilkan `SopVerificationModal`.
 6. Jika `sesuai` → auto-save ke galeri "BSS Parking".
 7. User Save → persist sebagai `SubmissionModel` + tampilkan SnackBar.

### 4.3 Watermark (Real-time + Burned)
- **Live preview widget** (`LiveTimemarkWatermarkWidget`): 1-second ticker, white card dengan badge tag + jam monospace + logo + baris metadata (tanggal, alamat, GPS).
- **Burned watermark** (`ImageWatermarkProcessor.applyWatermarkToFile`): decode → scale 1440px → draw via Canvas (shadow + white card + amber badge + digital clock + logo/BSS-PARKING text + metadata block dengan left accent bar) → encode PNG → overwrite file.
- **Customizer modal** (`WatermarkCustomizerModal`): upload logo (galeri, max 600×300), edit tag text, pilih warna (7 palette: BSS Blue/Amber/Sky/Emerald/Purple/Red/Dark Slate), toggle show-location-on-camera/on-result, live preview card.
- **Card templates** (`CardTemplateManagementScreen`): preset badge+logo+color combo (mis. PBM/PKM Standar), tap untuk apply sebagai watermark config.
- **Default fallback**: jika user belum set → badge "PBM/PKM" amber + logo text "BSS/PARKING".

### 4.4 GPS / Lokasi
- **Real-time GPS** via `geolocator` (accuracy: medium, 2s timeout).
- **15s cache** untuk hindari freeze UI.
- **Reverse geocoding** (geocoding) — refresh hanya kalau user pindah >50m.
- **Fallback**: jika GPS off → pos seed + random jitter ±0.00002° (terlihat natural).
- **Permission check**: `ensureLocationPermission()` → request jika denied.
- **Pos management**:
 - `PosLocation` model: posId, posName, cabangName, fullAddress, locationTag, tagColor, lat, lng.
 - Default seed: `POS-01` Calaca Wenang, Manado.
 - CRUD lengkap di `LocationManagementScreen` (tambah/edit/hapus + pilih aktif).
 - Modal picker `LocationPickerModal` urutkan pos by jarak dari GPS live.
 - Simpan GPS saat ini sebagai pos baru (opsional).

### 4.5 Template SOP (CRUD)
- **List** (`TemplateListScreen`): ExpansionTile per template, show kategori icon + nama + deskripsi + count kriteria SOP + list kriteria + tombol Edit/Hapus + FAB "Buat Template" + AppBar reset-to-defaults.
- **Editor** (`TemplateEditorScreen`): Form nama + kategori dropdown + deskripsi + switch wajib-GPS + dynamic list kriteria (add via TextField, hapus per-item, min 1).
- **Kategori** (`TemplateCategory`): `absensi` / `briefing` / `lokasi` / `custom` + displayName Indonesia.
- **Default templates** (4 hardcoded): Absensi, Briefing Operasional, Kondisi Pos, Inspeksi Custom.
- **Persistence**: `TemplateRepository` → `StorageService` (key `bss_templates`).
- **Update timestamp**: auto-stamp `updatedAt: DateTime.now()` di `updateTemplate`.

### 4.6 Verifikasi SOP — AI Vision
- **Service** (`AiVisionService`): single entry `verifyPhoto(template, imageBase64, customConfig?, forceSimulateSuccess?, forceSimulateFailure?)`.
- **2 mode**:
 - **On-device mock**: keyword-classify criteria, return random success/fail.
 - **Cloud LLM**: POST ke OpenAI-compatible `/chat/completions` (configurable endpoint/model/API key).
- **Default endpoint**: Omniroute `gemini-3.7-flash-high` (configured di test scripts).
- **Response JSON**: `{status, confidenceScore, alasan, poinLolos[], poinGagal[]}`.
- **Status mapping**: `sesuai` / `tidak_sesuai` / `perlu_cek_manual`.
- **`SopCriteriaHelper`**: 20+ known opposite pairs (seragam, ID card, rambut, sepatu, wajah, dll) + heuristics (prefix "tidak ada"/"bebas dari", suffix "bersih"/"rapi"/"terpasang") → convert positive criteria → negative statement saat gagal.
- **Feature toggles** (di config): enableGroomingCheck / enableIdCardDetection / enableFormationCheck / enableCleanlinessCheck → filter criteria sebelum dikirim.
- **Fallback policy**: jika cloud AI fail/timeout → return `tidak_sesuai` dengan alasan eksplisit "Foto dialihkan untuk Cek Manual oleh Supervisor, bukan otomatis lolos" (intentional UX, bukan bug).
- **Result model** (`AiVerificationResult`): status, alasan, poinGagal, poinLolos, confidenceScore, providerName, isFallback, getter `isSesuai`.

### 4.7 Modal Hasil Verifikasi
- **Tipe**: bottom sheet rounded-top dengan drag handle.
- **Fallback banner**: muncul jika `isFallback` (server AI offline) → wifi-off icon + "SERVER AI OFFLINE".
- **Hero status card**:
 - `sesuai` (success hijau) → icon `verified_rounded` + confidence bar.
 - `tidak_sesuai` (danger merah) → icon `gpp_bad_rounded` + confidence bar.
 - `perlu_cek_manual` (warning orange) → icon `shield_moon_rounded`.
- **Meta info bar**: kode verifikasi (monospace) + template name chip.
- **AI explanation**: "Catatan AI Vision" + block text alasan.
- **Poin gagal** (list item red bg + cancel icon) + **Poin lolos** (list item green bg + check icon).
- **Action dock**:
 - Jika gagal: red "Foto Ulang Sekarang" + outlined "Batal & Tutup" (modal blocking).
 - Jika lolos/manual: primary "Simpan & Kirim"/"Kirim (Cek Manual)" + Telegram button (warna #229ED9) + outlined "Foto Ulang" + "Batal & Tutup" text button.

### 4.8 Riwayat Submission
- **List** (`HistoryListScreen`):
 - Stats bar atas: Total Foto / Lolos SOP / Ditolak / Kepatuhan %.
 - Search field (kode verifikasi / template / petugas).
 - Filter chips: Semua / Lolos / Ditolak / Perlu Cek.
 - ListView submission cards: thumbnail 64×64 + status badge + kode + template + user + pos + timestamp.
 - Tap → push `HistoryDetailScreen`.
 - Auto-refresh via `SubmissionRepository` listener.
- **Detail** (`HistoryDetailScreen`):
 - Watermarked photo (full).
 - Share ke Telegram + Save ke galeri buttons.
 - Status banner.
 - Override note (jika supervisor override).
 - AI reason card (alasan + poin gagal + poin lolos).
 - Metadata lengkap (timestamp, lokasi, kode, template, petugas, pos, cabang).
 - **Supervisor/HO only**: tombol Override → set status baru + note + supervisor name.

### 4.9 Profil & Logout
- **Profile header card** (primary bg): avatar initial + nama + NPP + email + role chip.
- **Pos card**: pos aktif + cabang + tombol "Ganti Pos" (buka dialog list).
- **Action tiles**:
 - Ganti Role Akun Demo (switch user).
 - Reset Data Demo & Template (kembalikan template + log ke default).
 - Keluar / Logout (clear session + push LoginScreen).
- **Footer branding**: "BSS PARKING TIMEMARK • PT. BAHANA SULUT SENTOSA • Versi 1.0.0".

### 4.10 Pengaturan AI Vision
- **Provider & endpoint config**: API key (obscured + show toggle), base URL, model name, custom prompt.
- **Connection test**: button "Uji Koneksi AI" → POST ping "Ping test BSS Parking" → tampil latency + status (8s timeout).
- **Confidence slider**: 50–100%.
- **Feature toggles**: 4 switch (Grooming/ID Card/Formation/Cleanliness).
- **Actions**: Reset Default + Simpan Pengaturan.
- **Persistence**: `AiVisionService.updateConfig()` → `StorageService` (key `bss_ai_vision_config`).

---

## 5. Alur Aplikasi End-to-End

### 5.1 Main Navigation
```
main.dart
  └─ BssParkingTimemarkApp
       └─ CameraCaptureScreen (home, default)
        └─ (jika via login) LoginScreen → pushReplacement → MainShellScreen
            └─ IndexedStack (4 tabs, state preserved):
                 [0] CameraCaptureScreen
                 [1] HistoryListScreen
                 [2] TemplateListScreen
                 [3] ProfileScreen
            └─ BottomNavigationBar (Kamera / Riwayat / SOP / Profil)
```

### 5.2 User Flow: Petugas ambil foto
```
1. Login → MainShellScreen (tab Kamera)
2. CameraCaptureScreen init:
   - Init CameraController (720p/1080p)
   - Hydrate WatermarkConfig dari storage
   - Load active pos dari LocationService
   - Generate GPS via getCurrentLocation()
3. Tap shutter:
   ├─ _isProcessingAI = true (scrim overlay)
   ├─ generateCode(timestamp, lat, lng, userId) → BSS-XXXXXXXX
   ├─ takePicture() → XFile path
   ├─ generateAiVisionBase64() (thumbnail 720px JPEG)
   ├─ applyWatermarkToFile() (burn watermark, fire-and-forget)
   ├─ AiVisionService.verifyPhoto(template, base64)
   │    ├─ mock mode: keyword classify → random result
   │    └─ cloud mode: POST ke endpoint → parse JSON
   │         └─ fallback: jika error → return perluCekManual (NOT auto-lolos)
   └─ showModalBottomSheet → SopVerificationModal
        ├─ Display: status + confidence + alasan + poin gagal/lolos + kode
        └─ User actions:
             ├─ Simpan → SubmissionRepository.addSubmission() + save to galeri
             ├─ Foto Ulang → close modal, ready for next capture
             ├─ Batal → close modal
             └─ Share Telegram → ShareHelper.shareToTelegram()
```

### 5.3 User Flow: Supervisor override submission
```
1. Riwayat tab → HistoryListScreen
2. Tap submission card → HistoryDetailScreen
3. (jika role supervisor/ho) Tap "Override Hasil Verifikasi"
4. Dialog: pilih status baru + tulis note
5. SubmissionRepository.overrideSubmissionStatus() → update + persist + notify
6. UI refresh via listener → tampil note + status baru
```

### 5.4 Data Persistence Flow
```
Init: StorageService.init() → SharedPreferences.getInstance()
      → TemplateRepository.init() (seed 4 defaults if empty)
      → SubmissionRepository.init() (load list)
      → AuthRepository.init() (load user or fallback to demo[0])

Mutation flow (e.g., addSubmission):
  Repo.add() → in-memory insert → StorageService.save() (JSON encode)
           → notifyListeners() → all listening UI rebuild
```

---

## 6. Data Model

### TemplateModel
```dart
{
  id: 'tpl_XXXXXXXX',
  nama: 'Absensi Masuk Shift Siang',
  deskripsi: '...',
  jenis: TemplateCategory (absensi|briefing|lokasi|custom),
  wajibLokasi: bool,
  sopCriteria: [String],          // list teks kriteria
  contohFotoDescriptions: [String],
  createdBy: 'Supervisor' | 'System',
  updatedAt: DateTime
}
```

### SubmissionModel
```dart
{
  id, templateId, templateName,
  userId, userName, userNpp,
  posId, posName, cabangName,
  imageBase64?, imagePath?,
  timestampCapture, timezone (default 'WIB'),
  lat?, lng?, akurasiMeter?,
  kodeVerifikasi,                  // 'BSS-XXXXXXXX'
  status: VerificationStatus,
  alasanAI,
  poinGagal: [String],
  poinLolos: [String],
  isOfflineQueue: bool,
  overrideNote?, overriddenBy?,
  createdAt
}
```

### UserModel
```dart
{ id, nama, npp, email, role, posId, posName, cabangName }
```

### AiVisionConfig
```dart
{
  provider: AiProviderType (customEndpoint|geminiVision|claudeVision|onDeviceMock),
  endpointUrl, apiKey, modelName, customPrompt,
  timeoutSeconds (15),
  fallbackBehavior,
  enableGroomingCheck, enableIdCardDetection,
  enableFormationCheck, enableCleanlinessCheck
}
```

### WatermarkConfig
```dart
{
  logoImagePath?,
  badgeTag (default 'PBM/PKM'),
  badgeColor (default amber #F59E0B),
  timeZone (default 'WITA'),
  showLocationOnCamera (true),
  showLocationOnResult (true)
}
```

### PosLocation
```dart
{ posId, posName, cabangName, fullAddress, locationTag, tagColor, lat, lng }
```

---

## 7. Kode Verifikasi (Tamper-Evident)

```dart
VerificationCodeGenerator.generateCode(
  timestamp: DateTime,
  lat?: double,
  lng?: double,
  userId?: String,
) → 'BSS-' + SHA-256(epoch + lat + lng + userId + salt).hex[:8]
```

- **Salt**: `Random.secure().nextInt(1e6)` → unik per generate.
- **Deterministic** untuk input+seed yang sama, **collision-resistant** antar submission.
- Dicetak di watermark + metadata log (FR-12 PRD terpenuhi).

---

## 8. SOP Standar yang Didukung

1. **Grooming & Atribut Petugas**:
 - Seragam resmi BSS Parking bersih, rapi, terkancing.
 - ID Card / Name Tag di saku kiri, terbaca jelas.
 - Rambut / jilbab rapi sesuai standar.
 - Sepatu dinas hitam (pantofel / PDL).
 - Wajah terlihat jelas (tanpa masker/kacamata hitam).
2. **Kesiapan Pos & Lajur**:
 - Booth bebas tumpukan barang.
 - Barrier gate, sensor loop, rambu tarif jelas.
 - Tidak ada genangan/sampah.
 - Lampu penerangan menyala.
3. **Peralatan Kerja & Kasir**:
 - EDC & printer karcis online.
 - Roll kertas karcis (cadangan min 2).
 - Laci kasir terkunci, meja rapi.
 - HT & senter siap.

---

## 9. Testing Suite

| File | Tipe | Coverage |
|---|---|---|
| `test/widget_test.dart` | Smoke + util | App render, verification code format, timemark format, GPS format, date ID |
| `test/ai_vision_test.dart` | Unit + widget | AiVisionConfig serialization, parseResponse JSON sanitization, settings screen render |
| `test/sop_criteria_opposite_test.dart` | Unit | SopCriteriaHelper positive↔negative conversion, force-fail/success mock |
| `test/watermark_persistence_test.dart` | Unit | WatermarkConfig JSON round-trip, default fallback |
| `test/template_deletion_test.dart` | Unit | Delete by id, reset to defaults |
| `test_ai_latency.py` | Integration | Live API latency (dark/kaos/ADB capture cases) |
| `test_benchmark.py` | Integration | Baseline benchmark (640×800, verbose prompt) |
| `test_optimized_latency.py` | A/B test | Optimized prompt (480×640, shorter, lower max_tokens) |

---

## 10. Strengths (Positif)

1. **Struktur modular clean** — separation core/data/features sesuai best practice Flutter.
2. **Listener pattern** (ChangeNotifier) ringan, no boilerplate BLoC.
3. **Mock-first AI** → app jalan tanpa backend, demo-friendly.
4. **Watermark burned** (bukan overlay UI) → anti-screenshot-proof sesuai PRD FR-4.
5. **Graceful fallback** AI → manual review (tidak auto-lolos saat server error).
6. **Kode verifikasi SHA-256** → tamper-evident + unique per submission.
7. **Rich SOP criteria helper** → positive-to-negative statement conversion untuk UX clarity.
8. **Comprehensive tests** — model serialization, widget render, AI parsing.
9. **UX lengkap** — filter history, search, stats bar, override supervisor, share Telegram, save galeri.
10. **Mock + Cloud dual-mode** — switch endpoint tanpa code change.

---

## 11. Risk & Tech Debt (Catatan Audit)

1. **Tidak ada backend** — semua data di `SharedPreferences` lokal device (PRD FR-15 tidak terpenuhi: "data riwayat di backend, bukan lokal").
2. **No auth real** — login hanya pilih user demo, no password (PRD FR-16 minimum terpenuhi demo).
3. **Tidak ada HTTPS pin / cert validation** — cloud AI call raw HTTP (PRD NFR-3 tidak terpenuhi).
4. **Anti-fake-GPS belum** — pakai `geolocator` langsung tanpa cek `isMockLocation` (PRD §12 dicatat v2).
5. **EXIF metadata belum diproses** — foto capture tanpa validasi metadata waktu (PRD §12 dicatat v2).
6. **No offline queue** — submission langsung tersimpan, tidak ada antrian offline (PRD NFR-2 tidak terpenuhi).
7. **No pagination** di history list — bisa lag jika ribuan submission.
8. **Hardcoded seed** — pos default 1 entry (Manado), user demo 3, tidak ada flow create user from UI.
9. **API key di SharedPreferences** (plain) — bukan secure storage (PRD NFR-3 partial).
10. **No image compression** sebelum upload — base64 thumbnail generate on-the-fly (quality 72, max 720px) sudah OK, tapi file asli bisa >5MB.
11. **No retry/backoff** di HTTP call ke AI (8s timeout hard).
12. **Telegram share pakai URL launcher** — fragile jika app Telegram tidak terinstall.
13. **Race condition potential**: `applyWatermarkToFile` fire-and-forget — user bisa Save sebelum watermark selesai diburn.

---

## 12. Build & Run

```bash
# Install deps
flutter pub get

# Run
flutter run                          # device/emulator default
flutter run -d <deviceId>            # specific device
flutter run --release                # production mode

# Build APK/IPA
flutter build apk --release
flutter build appbundle --release
flutter build ios --release

# Test
flutter test                         # all Dart tests
flutter test test/ai_vision_test.dart

# Lint
flutter analyze
```

---

## 13. Ringkasan Final

**BssparkingTimeMark** adalah aplikasi Flutter MVP yang solid untuk kamera verifikasi SOP petugas BSS Parking. Fitur utamanya: kamera native + watermark burned (waktu/GPS real-time, anti-manipulasi) + kode verifikasi SHA-256 + AI Vision verifier (mock + cloud) + CRUD template SOP + manajemen pos + riwayat submission dengan filter & supervisor override + share ke Telegram + save ke galeri.

**Stack**: Flutter 3.11+ Material 3, package `camera`/`geolocator`/`geolocoding`/`gal`/`share_plus`/`image`/`crypto`/`http`/`google_fonts`.

**Arsitektur**: Repository pattern singleton + ChangeNotifier, no DI framework, no router (MaterialPageRoute manual), SharedPreferences sebagai single persistence layer.

**Status PRD compliance**: FR-1, FR-2, FR-4, FR-5, FR-6, FR-8, FR-9, FR-10, FR-12, FR-13, FR-14, FR-17 terpenuhi (MVP scope). FR-3, FR-7, FR-11, FR-15, FR-16, NFR-2, NFR-3, NFR-4 terpenuhi sebagian (mock/local only).

**Rekomendasi next step**:
- Integrasi backend (Firebase/Node) untuk persistensi + sinkronisasi offline queue.
- Secure storage (`flutter_secure_storage`) untuk API key & user session.
- HTTP pinning + retry/backoff + circuit breaker.
- Mock-location detection.
- Pagination + infinite scroll di history.
- Hapus race condition watermark (await sebelum Save).
- Face-match ke foto profil petugas (v2).
