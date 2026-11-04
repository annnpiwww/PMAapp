# 🛡️ Security, QA & Verification Guidelines (Exclusive for Tukang Security)

Direktori ini adalah acuan terpusat standar keamanan, 7 OWASP guards, protokol TDD, dan pencegahan fraud untuk **Tukang Security & QA (`sec`)**.

## 🔒 Scope Access (mandortukangv2)
- ✅ **Tukang Security (`sec`)**: **WAJIB MEMBACA** file di folder ini sebagai benchmark keamanan, audit celah, penulisan test suite, dan verifikasi kelayakan sebelum report DONE.
- ❌ **Tukang Design (`ui`)**: DILARANG membaca folder ini (di luar scope styling/UI).
- ❌ **Tukang Coder (`coder`)**: DILARANG membaca folder ini (di luar scope logika murni).
- 👑 **Mandor**: Jangan masukkan folder ini ke `allowed_files` (itu izin edit). `orca-bridge` otomatis menambahkan baris `REFS docs/security_references/` (read-only) di setiap handoff ke `sec`.

## 📁 Jenis File yang Bisa Ditaruh di Sini:
1. **Security & QA Specification**: `security_qa_guidelines.md` (7 OWASP guards, 4 Karpathy principles, anti-fraud time mark, TDD protocol).
2. **Audit History & Vulnerability Logs**: Laporan audit terdahulu (seperti temuan P0/P1, pentest report, RLS lockdown).
3. **Security Test Cases**: Checklist pengujian penetrasi (SQLi, auth bypass, IDOR, brute-force rate limit).
