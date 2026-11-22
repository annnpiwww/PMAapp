# PMApp In-App Updater Mockups (P2)

Visual design and interactive specification for PMApp self-updater (`U1` to `U5` technician flow) and publisher release management (`A1` to `A2`). Extends `docs/design/DESIGN.md` (Mode: Operate, Dials: ENERGY 2 / RHYTHM 2 / MOTION 1).

## 1. Screen List

| ID | File | Purpose | Rendered PNGs |
|---|---|---|---|
| U1 | `u1.html` | Optional update bottom sheet over dimmed Daily Task screen | `png/u1-light.png`, `png/u1-dark.png` |
| U2 | `u2.html` | Active download progress inside version ticket | `png/u2-light.png`, `png/u2-dark.png`, `png/u2-360-light.png` |
| U3 | `u3.html` | First-time Android install permission explainer (3A) + Verified ready state (3B) | `png/u3-light.png`, `png/u3-dark.png` |
| U4 | `u4.html` | Mandatory full-screen block with inline progress (zero dismiss/back path) | `png/u4-light.png`, `png/u4-dark.png`, `png/u4-360-light.png` |
| U5 | `u5.html` | Error state board (no internet, interrupted resumable, corrupt file, storage full) | `png/u5-light.png`, `png/u5-dark.png` |
| A1 | `a1.html` | Publisher release list (`Rilis aplikasi`): active per ABI + history + upload CTA | `png/a1-light.png`, `png/a1-dark.png` |
| A2 | `a2.html` | Upload APK form (2A) + Publish confirm dialog (2B) + Rollback confirm dialog (2C) | `png/a2-light.png`, `png/a2-dark.png` |
| Board | `png/board.png` | Overview board of all 7 screens (light theme, 390px columns) | `png/board.png` |

## 2. Entry Point Decisions

- **Technician (`U1`..`U5`)**: Triggered on app launch (`SplashScreen`) or resume from background when `POST /functions/v1/app-releases` (`action: "latest"`) returns `update: true`. Optional updates show `U1` over the home/Daily Task screen; mandatory updates (`mandatory: true`) replace the route with non-dismissable `U4`.
- **Publisher (`A1`..`A2`)**: Entry row `Rilis aplikasi` placed inside the supervisor navigation drawer directly below `Penugasan Teknisi [SPV]`, rendered **only** when the signed-in user is in `RELEASE_PUBLISHER_UIDS`.
- **Technician copy guardrail**: `U1` through `U5` never mention `SHA`, `ABI`, `APK`, or `versionCode`.

## 3. Data Mapping

| UI Element | Source Field / Calculation | Formatting & Edge Case | Screens |
|---|---|---|---|
| Current version | `PackageInfo.version` | `v2.0.141` | U1, U2, U3, U4, U5 |
| New version | `release.version_name` | `v2.0.142` | U1..U5, A1, A2 |
| File size | `release.size_bytes` | 1 decimal MB, comma (`24,9 MB`) | U1..U5, A1, A2 |
| Release notes | `release.changelog` | Plain text lines; if empty/null, hide section | U1, A1, A2 |
| Mandatory flag | `response.mandatory` | `true` routes to U4; `false` routes to U1 | U1, U4, A1, A2 |
| Progress % & MB | `downloadedBytes / size_bytes` | `48%`, `12,0 / 24,9 MB`, tabular numerals | U2, U4, U5 (5B) |
| Download speed | Client rolling byte rate | `1,2 MB/dtk` | U2, U4 |
| Remaining time | Client `(remaining / speed)` | `sekitar 18 dtk` | U2, U4 |
| Integrity check | Client SHA-256 vs `release.sha256` | Shown as step `Memeriksa keaslian file` / `Keaslian file terverifikasi`; hash hidden | U2, U3, U4, U5 (5C) |
| Publisher list | `action: "list"` rows | ABI shown as `arm64`/`arm32`; statuses `draft`/`published`/`rolled_back`/`archived` -> `Draf`/`Aktif`/`Ditarik`/`Arsip`; date `dd MMM yyyy HH.mm`; `created_by` name | A1 |
| Upload APK metadata | Device APK parser | File name + size, read-only `version_name`, `version_code`, `abi` | A2 |
| Upload form inputs | Publisher user input | `changelog` textarea (max 2000), `Wajib diperbarui` switch, optional `Versi minimum` (`x.y.z`) | A2 |

## 4. Component & State Matrix

| Component | Default | Pressed / Active | Disabled / Waiting | Dark Mode | Notes |
|---|---|---|---|---|---|
| Primary pill button | `#1A428A` bg, `#FFFFFF` ink, `52px` | `#143672` bg, `scale(0.97)` | `#EFEFEF` bg, `#5E5E5E` ink | `#FFFFFF` bg, `#000000` ink, pressed `#E2E2E2` | Pinned in thumb zone |
| Secondary outline button | `1.5px` `#1A428A` border, `48px` | `scale(0.97)` | Not used | `1.5px` `#FFFFFF` border, `#FFFFFF` ink | `Nanti`, `Batalkan`, `Tarik rilis` |
| Version ticket cell | `#2A549C` bg, `1.5px` `#8EA3D3` border, `12px` radius | Non-interactive | Progress bar inside ticket (`#40649F` track, `#FFFFFF` fill) | `#1F1F1F` bg, `#6A6A6A` border, `#2E2E2E` track | Signature motif inside band |
| Status pills (A1) | Icon + text (`Aktif`, `Draf`, `Ditarik`, `Arsip`) | Non-interactive | Non-interactive | High-contrast dark equivalents | Never color-only |
| Error markers (U5) | Orange `!` with white/ink ring (`#FF6500`); Danger `×` (`#C81E1E` on `#FBE9E9`) | Non-interactive | Non-interactive | `#FF8A3D` text, `#FF9B9B` on `#3A1616` | Every error gives cause + 1 recovery CTA |
| Switch (`Wajib diperbarui`) | `52x32` track inside `56x48` hit box | Knob shifts right, primary fill | N/A | Inverted primary fill | `role="switch"`, `aria-checked` |

## 5. Interaction & Motion Choreography (`MOTION 1`)

### Choreography Table

| Element | Role | Trigger | Motion | Curve | Duration | Reduced-Motion Fallback |
|---|---|---|---|---|---|---|
| Update bottom sheet (`U1`..`U3`) | Lead | Update detected / state change | `translateY(16px -> 0)` + `opacity(0.92 -> 1)` | `--ease-out` (`cubic-bezier(0.23, 1, 0.32, 1)`) | `220ms` | Instant (`1ms`) opacity/state switch |
| Progress fill inside ticket (`U2`, `U4`) | Support | Download chunk tick | `transform: scaleX(p)` from left | `--ease-out` | `220ms` | Instant step update, numeric %/MB always updated |
| Verified check badge (`U3` 3B) | Lead | Verification passes | `scale(0.94 -> 1)` + `opacity(0.85 -> 1)` | `--ease-out` | `220ms` | Instant visible check |
| Error card swap (`U5`) | Lead | Network/disk failure | `translateY(6px -> 0)` + `opacity(0.92 -> 1)` | `--ease-out` | `180ms` | Instant swap |
| Buttons & icon circles | Support | Press (`:active`) | `scale(0.97)` + bg darken | `--ease-out` | `100ms` | Bg darken only, no scale |

### What Stays Static & Why

- **Band perforation notches and `v2.0.141 -> v2.0.142` labels**: Anchor eye-tracking so technicians reading under sunlight glare do not lose the version numbers.
- **Step lists, release notes, and publisher history rows**: High-frequency operational data must appear immediately with zero stagger or fade-up delay (`ux-motion-20` principle 20).
- **Mandatory block (`U4`)**: No decorative motion or pulse; calm, high-contrast layout signals blocking state clearly.

### `ux-motion-20` Checklist C

1. Purpose & frequency test: PASS (220ms sheet/check/progress, 100ms press, zero list stagger, zero loops).
2. Tokens only, no `ease-in`, no `scale(0)`: PASS (`--ease-out`, start scale `0.94` / `0.97`).
3. Only `transform` and `opacity` animated: PASS (`scaleX`, `translateY`, `scale`, `opacity`).
4. `prefers-reduced-motion: reduce` supported + text never motion-only: PASS.
5. Touch targets `>= 44px` (`>= 48px` primary/rows) and 1 primary CTA per view: PASS.
6. Forms/steps chunked, feedback <100ms, progress shows numeric % + MB + speed + ETA: PASS.
7. Errors preserve partial download / form input and name recovery action: PASS.
8. Rendered proof at 390px + 360px + light/dark: PASS.

## 6. Acceptance Criteria for P3 Implementation (Given / When / Then)

1. **Optional update presentation (`U1`)**:
   - **Given** `latest` returns `update: true` and `mandatory: false`
   - **When** PMApp opens or resumes from background
   - **Then** the `U1` bottom sheet opens over the current screen showing `v<current> -> v<new>`, formatted size (`XX,X MB`), collapsible `Catatan rilis` (hidden completely if `changelog` is null or whitespace), primary `Perbarui sekarang`, and secondary `Nanti`.
2. **Mandatory update block (`U4`)**:
   - **Given** `latest` returns `update: true` and `mandatory: true`
   - **When** the update screen is shown
   - **Then** `U4` renders full-screen with `Versi ini sudah tidak didukung. Perbarui untuk lanjut bekerja.`, has no `Nanti` button, no close button, and system Back / swipe-back does nothing.
3. **Download progress & verification (`U2`, `U3`)**:
   - **Given** the technician taps `Perbarui sekarang`
   - **When** bytes stream to local cache
   - **Then** the progress bar inside the version ticket updates with numeric percentage, `x,x / XX,X MB`, speed (`X,X MB/dtk`), and remaining time (`sekitar N dtk`), followed automatically by silent client SHA-256 verification without displaying the hash or the words `SHA`, `ABI`, `APK`, or `versionCode`.
4. **Android unknown-apps permission (`U3`)**:
   - **Given** verification succeeds and `canRequestPackageInstalls` is `false`
   - **When** transitioning to ready-to-install
   - **Then** `U3` (3A) explains why, displays the 3 steps with the `Izinkan dari sumber ini` illustration, and `Buka pengaturan` opens the package-specific Android settings page; once granted, `U3` (3B) displays `Siap dipasang` and `Pasang sekarang` launches the system APK installer.
5. **Resumable & recoverable errors (`U5`)**:
   - **Given** a download drops mid-stream, fails verification, lacks internet, or lacks disk space
   - **When** the failure occurs
   - **Then** `U5` displays the specific cause and recovery CTA (`Lanjutkan unduhan` keeping downloaded bytes on connection drop, `Unduh ulang` clearing corrupt partial file on hash mismatch, `Coba lagi` on offline/storage full).
6. **Publisher release flow (`A1`, `A2`)**:
   - **Given** a user whose `uid` is in `RELEASE_PUBLISHER_UIDS` opens the SPV drawer
   - **When** they tap `Rilis aplikasi`
   - **Then** `A1` shows active releases per ABI (`arm64`, `arm32`), history with icon+text status pills (`Draf`, `Aktif`, `Ditarik`, `Arsip`), and `Unggah APK` opening `A2`; publishing displays `Teknisi akan mendapat pembaruan ini saat membuka aplikasi.` and rollback displays `Menarik rilis hanya menghentikan HP yang belum memperbarui. HP yang sudah memperbarui tidak bisa turun versi; untuk membatalkan, unggah versi perbaikan dengan nomor lebih tinggi.`
