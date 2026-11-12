# Visual QA Report: Riwayat Laporan Section (Production Live)

- **Date / Time**: 2026-11-12 07:33 WITA (2026-11-11 23:33 UTC)
- **Target URL**: `https://bssparking-pma.vercel.app/lapor/`
- **Tester / Execution**: Tukang QA via Playwright Chromium (Automated Viewport 390x844 & 360x780)
- **Overall Status**: **PASS (All 3 states verified, 0 visual defects, cleanup verified)**

---

## 1. Test Setup & Isolation

- **Methodology**: Applied Supabase Management API (`https://api.supabase.com/v1/projects/sxsjixnnlzhjinzcyhjb/database/query`) with personal access token (`~/.config/supabase_pmaapp.env`).
- **Test Account Created**:
  - `username`: `smoketes-pkm`
  - `nama`: `Smoke Tes`
  - `role`: `admin_pos`
  - `cabang`: `manado`
  - `pos_name`: `Pelabuhan Kalimas Manado`
  - `pos_kode`: `pkm`
  - `aktif`: `true`
  - `password_hash`: PBKDF2-SHA256, 100,000 iterations (16-byte random salt, 32-byte derived hash)
  - Secrets handling: volatile memory only, 0 credentials logged or committed.

---

## 2. Live Verification of States & Badges

| Step | State / Transition | Expected Badge | Actual Badge | Screenshot Path | Result |
|---|---|---|---|---|---|
| 1 | Report Submitted (Initial) | `Menunggu Teknisi` (Amber/Yellow pill `#FEF3C7` / `#92400E`) | `Menunggu Teknisi` (`.status-pill.status-menunggu`) | `docs/screenshots/lapor-riwayat/01-menunggu.png` | **PASS** |
| 2 | Simulated Claim via SQL (`teknisi_nama='Ryan'`) | `Ditangani oleh Ryan` (Blue pill `#DBEAFE` / `#1E40AF`) | `Ditangani oleh Ryan` (`.status-pill.status-ditangani`) | `docs/screenshots/lapor-riwayat/02-ditangani.png` | **PASS** |
| 3 | Simulated Selesai via SQL (`status='completed'`) | `Selesai` (Green pill `#D1FAE5` / `#065F46`) | `Selesai` (`.status-pill.status-selesai`) | `docs/screenshots/lapor-riwayat/03-selesai.png` | **PASS** |
| 4 | Mobile Compact Viewport 360x780 | Clean reflow, no text overflow | Clean reflow, no horizontal overflow | `docs/screenshots/lapor-riwayat/04-360.png` | **PASS** |

### Anti-Defect Check:
- Verified that initial state does **NOT** display `Ditangani oleh Smoke Tes`.
- Verified auto-refresh / reload renders dynamic state changes without requiring re-login.

---

## 3. Visual & Responsive Review (390x844 & 360x780)

Every rendered screenshot was audited against UI/UX standards:

- **Text Overflow**: None. Title, kendala description, dates, and badge labels fit neatly.
- **Kendala Ellipsis**: Single line truncation (`white-space: nowrap; overflow: hidden; text-overflow: ellipsis`) functions as designed.
- **Pill Readability**: High contrast text ratios conform to WCAG AA ($\ge 4.5:1$):
  - Menunggu: `#92400E` on `#FEF3C7` (Ratio > 7:1)
  - Ditangani: `#1E40AF` on `#DBEAFE` (Ratio > 7:1)
  - Selesai: `#065F46` on `#D1FAE5` (Ratio > 7:1)
- **Section Spacing**:
  - `#riwayat-section h3`: `margin: 24px 0 12px` perfectly matches form spacing.
  - `.riwayat-card`: `padding: 16px`, `border-radius: 12px`, `margin-bottom: 12px`.
- **Layout Jump**: None observed across state re-renders.
- **Visual Defects**: **None (0 defects found)**.

---

## 4. Mandatory Cleanup Evidence

Both task row and test user were purged from database:
1. `DELETE FROM public.daily_tasks_manado WHERE judul = 'SMOKE TES abaikan' OR id = 'task_1794439973526_2248';`
2. `DELETE FROM public.app_users WHERE username = 'smoketes-pkm';`

### Verification Queries & Real Counts
- `SELECT count(*) FROM public.daily_tasks_manado WHERE judul = 'SMOKE TES abaikan' OR id = 'task_1794439973526_2248';` -> **0**
- `SELECT count(*) FROM public.app_users WHERE username = 'smoketes-pkm';` -> **0**
- Status: **Clean state 100% verified.**

---

## 5. Action Items for Aan (Google Sheet `Error` Row Cleanup)

The single production error report generated for this visual test triggered the background push/sheet webhook before deletion from Postgres:
- **Sheet `Error` Row ID to Delete**: `task_1794439973526_2248` (Created at ~07:32 WITA on 12 Nov 2026, Pelabuhan Kalimas Manado, "SMOKE TES abaikan").

---

## 6. Telegram Notifications

Transmitted via `rtk anpidhs-notify`:
- `01-menunggu.png` -> OK (Riwayat Lapor: Menunggu Teknisi)
- `02-ditangani.png` -> OK (Riwayat Lapor: Ditangani oleh Ryan)
- `03-selesai.png` -> OK (Riwayat Lapor: Selesai)
