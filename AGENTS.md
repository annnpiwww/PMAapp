# BssparkingTimeMark — Agent Guidelines & Rules

Selamat datang di project **BssparkingTimeMark**.

---

## 🛑 ATURAN MUTLAK FORMAT OUTPUT & KOMUNIKASI (DILARANG MERAPATKAN TEKS)
1. **Dilarang keras membuang spasi atau menggabungkan kata-kata (Anti-Squished Output)**.
   - Jangan pernah menyambung kata seperti: `SkenarioKonkurensi`, `TemuanKritis(P0)`, `ujicobaoperasional`.
   - Gunakan spasi, pemisah baris (blank lines), tanda baca normal, dan format paragraf/markdown yang manusiawi dan mudah dibaca.
   - **TIDAK BOLEH** menggunakan gaya *caveman ekstrem* yang menghilangkan artikel/spasi/titik hingga teks rusak atau sulit dibaca.
2. **Keterbacaan Adalah Prioritas Utama**:
   - Berikan jeda baris kosong antar-bagian/paragraf.
   - Kode, path file, identifier, dan snippet markdown harus berada di dalam backtick terpisah atau blok kode yang rapi.
3. **Bahasa**: Santai, natural, jelas (Bahasa Indonesia santai / Gen-Z, istilah teknis tetap Bahasa Inggris).

---

## 📋 ATURAN MUTLAK: TODO TREE PROGRESS TRACKER (ALA OMP)
Setiap kali menerima tugas / instruksi baru (fitur, bugfix, refactor, audit, atau multi-step task), AI agent **WAJIB** menampilkan widget Todo Tree di awal respon dan meng-update statusnya di setiap langkah pengerjaan:
1. **Format Tree Visual**:
   - `☑ ~~[Deskripsi Task]~~` : Tugas yang sudah selesai (dicoret / strikethrough).
   - `⏳ [Deskripsi Task]` : Tugas yang sedang berjalan saat ini (*in progress*).
   - `⬜ [Deskripsi Task]` : Tugas yang masih menunggu antrean (*pending*).
2. **Struktur Percabangan Unicode**:
   Gunakan ranting pohon yang rapi:
   ```text
   📋 Todo (X tasks)
   ├── ☑ ~~Task 1 yang sudah selesai~~
   ├── ⏳ Task 2 yang sedang dikerjakan
   ├── ⬜ Task 3 berikutnya
   └── ⬜ Task terakhir
   ```
3. **Fungsi Utama**: Memberikan transparansi real-time kepada user mengenai alur pengerjaan task, urutan eksekusi, dan status terkini tanpa harus menerka-nerka.

---

## 🕸️ ATURAN MUTLAK: DUAL KNOWLEDGE GRAPH (CODEGRAPH + GRAPHIFY) & ZERO-GREP POLICY
1. **Mandatory Indexing (Wajib Otomatis)**:
   - **CodeGraph**: Jika direktori `.codegraph/` belum ada di root repo, agent **WAJIB OTOMATIS** menjalankan `codegraph init` sebelum melakukan tugas apapun.
   - **Graphify**: Jika direktori `graphify-out/` belum ada di root repo, agent **WAJIB OTOMATIS** menjalankan pipeline headless `graphify extract . --code-only && graphify cluster-only . && graphify export html` untuk menghasilkan visualisasi interaktif `graph.html`, knowledge graph `graph.json`, dan laporan arsitektur `GRAPH_REPORT.md`.
   - **Auto-Sync Update**: Setiap kali selesai modifikasi kode, jalankan `graphify update .` untuk memperbarui graph secara instan (AST-only).
2. **Prioritas Navigasi**:
   - **Simbol, Call Hierarchy & Blast Radius**: Prioritas 1 `codegraph_explore` (MCP), Prioritas 2 `codegraph explore` (CLI).
   - **Arsitektur Makro, Relasi Lintas Modul & Komunitas**: Gunakan `graphify query "<question>"`, `graphify path "<A>" "<B>"`, `graphify explain "<concept>"`, atau navigasi `graphify-out/GRAPH_REPORT.md`.
   - **Grep/Find**: HANYA jika file berada di luar index atau kedua tool sama sekali tidak tersedia.
3. **Peta Arsitektur**:
   - Peta relasi dan indeks kode tersimpan di `Memory/Codegraphs/BssparkingTimeMark-Architecture-Map.md` dan visualizer di `graphify-out/graph.html`.

---

## 🔥 Meta-Router Global: `gaskeun` & Core Modes (`ponytail` + `caveman`)
Semua AI agent (Mavis, Antigravity, Claude Code, Codex, DSH, dll.) **WAJIB** menerapkan prinsip permanen berikut di setiap prompt tanpa menunggu dipanggil manual:

1. **Auto-Active Core Modes (Always-On)**:
   - **Mode `/caveman` (Full/Terse)**: Buang basa-basi/fluff pembuka & penutup. Jawaban padat, ringkas, hemat token, substansi teknis 100% terjaga. Teks tetap berjarak spasi manusiawi, dilarang squished text/tanpa spasi.
   - **Mode `/ponytail` (Full/Lazy Senior Dev)**: Utamakan solusi paling sederhana, minimalis, dan terbukti berhasil. YAGNI (buang kebutuhan spekulatif), reuse kode/stdlib yang ada > no new deps > minimum lines of diff. Fix root cause, bukan symptom.
   - **Mode `/gaskeun`**: Bahasa Indonesia santai, natural, to the point. Kode & identifier tetap English. Kesimpulan di awal.

2. **Aturan Baca Wajib Setiap Turn**:
   - Setiap agent menerima prompt, **wajib membaca `AGENTS.md`** sebagai single source of truth aturan perilaku, eksekusi kode, dan interaksi.

---

## 📚 Aturan Wajib: Context7 MCP Reference
1. **Mandatory Documentation Lookup**:
   - Dilarang menebak syntax API / konfigurasi library & framework.
   - **Wajib** gunakan tool `context7` (`resolve-library-id` -> `query-docs`) untuk mengambil dokumentasi & kode resmi terkini.
2. **Config Location**: Konfigurasi MCP aktif di `.cursor/mcp.json` dan `.mcp.json`.
3. **Dokumentasi Lengkap**: Lihat [[Skills/Context7-MCP|Context7 MCP]] & [[Decisions/ADR-002-Mandatory-Context7-MCP|ADR-002]].

---

## 🧠 Aturan Utama: Obsidian Memory Vault Protocol

Setiap AI agent yang bekerja di repo ini **WAJIB** menyelaraskan dan memperbarui memori, dokumentasi arsitektur, codegraph, dan aturan agent ke Obsidian Vault:

📍 **Central Memory Vault**: `/home/annnpii/Product development annpii/Memory/`

### 📋 Checklist & Siklus Kerja
- [ ] **1. Verifikasi Dokumentasi**: Gunakan Context7 MCP untuk referensi library/framework.
- [ ] **2. Cek Konteks Proyek**: Baca catatan terkait di [[Projects/BssparkingTimeMark|BssparkingTimeMark Project Note]] dan [[Agents/Project-Rules/BssparkingTimeMark|BssparkingTimeMark Rules]].
- [ ] **3. Arsitektur & Codegraph**: Update `Memory/Codegraphs/` jika ada perubahan struktur atau eksekusi `graphify`.
- [ ] **4. Status Project**: Update `Memory/Projects/BssparkingTimeMark.md`.
- [ ] **5. Keputusan Arsitektur**: Catat di `Memory/Decisions/` jika ada ADR baru.
- [ ] **6. Session Log**: Catat ke `Memory/Changelog/`.

---

## 📌 Project Overview & Guidelines: BssparkingTimeMark

- **Aplikasi**: Sistem Manajemen Parkir & Time Mark (BssparkingTimeMark).
- **Tujuan**: Tracking waktu masuk/keluar kendaraan, kalkulasi durasi/tarif parkir, penandaan waktu (time marking), dan reporting operasional parkir.
- **Kualitas Kode**: Strict type safety, penanganan error tangguh, logging jelas.
- **UI/UX**: Clean layout, anti-slop, responsif, dan mudah dibaca di mobile/tablet/desktop.

---

## 🔗 Referensi Vault Terkait
- **Central Index**: [[Index|Memory Vault Index / MOC]]
- **Profil Proyek**: [[Projects/BssparkingTimeMark|BssparkingTimeMark Project Profile]]
- **Agent Rules Note**: [[Agents/Project-Rules/BssparkingTimeMark|BssparkingTimeMark Agent Rules]]
- **Master Guidelines**: [[Agents/Overview|Master Agent Guidelines]]

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read `antislop.md` (core) and then the skill for the task:
- UI / visual: `skills/antislop-ui/SKILL.md`
- Copy & text: `skills/antislop-copywriting/SKILL.md`
- People: `skills/antislop-human/SKILL.md`
- Mobile / responsive: `skills/antislop-layoutmobile/SKILL.md`
- Code comments: `skills/antislop-code/SKILL.md`
Before starting, ask the user when antislop applies: during the work, or after it is done.
<!-- antislop:end -->
