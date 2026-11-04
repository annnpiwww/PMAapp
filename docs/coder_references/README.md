# ⚡ Architecture & Logic Guidelines (Exclusive for Tukang Coder)

Direktori ini adalah acuan terpusat arsitektur, clean coding standards, dan pattern logika aplikasi untuk **Tukang Coder (`coder`)**.

## 🔒 Scope Access (mandortukangv2)
- ✅ **Tukang Coder (`coder`)**: **WAJIB MEMBACA** file di folder ini sebagai benchmark arsitektur, state management, penanganan error, dan efisiensi kode (The Ladder).
- ❌ **Tukang Design (`ui`)**: DILARANG membaca folder ini (di luar scope styling/UI).
- ❌ **Tukang Security (`sec`)**: DILARANG membaca folder ini (fokus pada test & validator).
- 👑 **Mandor**: Jangan masukkan folder ini ke `allowed_files` (itu izin edit). `orca-bridge` otomatis menambahkan baris `REFS docs/coder_references/` (read-only) di setiap handoff ke `coder`.

## 📁 Jenis File yang Bisa Ditaruh di Sini:
1. **Architecture Blueprint**: `architecture_code_guidelines.md` (standar arsitektur, pattern repository, offline syncing, state management).
2. **Code Snippets / References**: File referensi kode `.dart`, `.ts`, atau `.sql` yang menurut lo memiliki arsitektur paling bersih dan elegan.
3. **API & Database Contracts**: Skema database Supabase, kontrak relasi tabel, dan pola query efisien.
