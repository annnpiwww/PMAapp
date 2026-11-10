---
version: 2
name: PMA App "Tiket"
source: Structure adapted from VoltAgent/awesome-design-md `design-md/uber/DESIGN.md` (pill actions, flat rows, few colors). Brand color and theme split decided by Aan on 2026-11-09.
dial: ENERGY 2 / RHYTHM 2 / MOTION 1
mockup: docs/design/redesign-v3/pma-tiket-hitam.figcraft
---

# PMA App DESIGN.md

Design Read: operational mobile app for parking technicians and SPV (KC Manado, KC Bali, HO Makassar), used one-handed outdoors, in a flat Uber-style language with a BSS blue band (`#1A428A`) in light mode and a black band in dark mode, dial ENERGY 2 / RHYTHM 2 / MOTION 1.

Flows, data, features, and button labels stay exactly as the app has them today. This file changes look and layout only. The burned-in photo watermark (`InteractiveWatermark`, `WatermarkPainter`) is out of scope and stays unchanged.

## Why this direction

- Technicians read the screen in sunlight. Big contrast steps (blue or black band, white body, black text) survive glare better than the old cream and navy mix.
- Each screen answers one question, so each screen gets one big number in the band.
- Safety orange already lives in the shutter and the watermark. It stays as the only attention color.

## Colors

All ratios below were measured with `antislop-human/contrast-check.py`.

### Light mode (default)

| Token | Hex | Use | Ratio |
|---|---|---|---|
| canvas | `#FFFFFF` | Screen body | |
| ink | `#000000` | Content text | 21:1 on canvas |
| band / primary | `#1A428A` | Header band ("tiket") and everything tappable on white: primary button, FAB, selected segment, radio, secondary outline and its text. BSS blue from `app_colors.dart:5`, picked by Aan on his phone after `#14046C` (hue 249°) showed as purple on vivid phone screens | white on blue 9.59:1, blue on white 9.59:1 |
| band-raise | `#2A549C` | Controls and cells on the band | white text 7.38:1 |
| band-line | `#8EA3D3` | 1.5px ring around band controls | 3.80:1 vs band |
| band-caption | `#D3DDF2` | Secondary text on the band; also the empty status ring on the band (grey would be 2.14:1) | 7.03:1 band, 5.41:1 band-raise |
| band-track | `#40649F` | Unfilled progress segments | white segment 5.93:1 vs track |
| body | `#5E5E5E` | Secondary text | 6.48:1 |
| mute | `#8A8A8A` | Chip and segmented borders, empty status ring | 3.45:1 (non-text) |
| soft | `#EFEFEF` | Dropdown fields, disabled button, neutral chips | body text 5.64:1 |
| hairline | `#E2E2E2` | Row dividers (decorative) | |
| signal | `#FF6500` | Needs attention: temuan, pending, offline, shutter | black text 7.11:1 |
| signal-text | `#B34700` | Orange text on white ("Proses 3/6 poin", late time) | 5.50:1 |
| ok | `#0E8345` | Done / aman: marker, chip fill, text | 4.83:1 (white on ok 4.83:1) |
| danger | `#C81E1E` on `#FBE9E9` | Destructive and "Urgent" only | 4.90:1 |

### Dark mode

| Token | Hex | Use | Ratio |
|---|---|---|---|
| canvas | `#141414` | Screen body | |
| text | `#FFFFFF` | Text | 18.42:1 |
| band | `#000000` | Header band | |
| band-raise | `#1F1F1F` | Controls on the band | white 16.48:1 |
| band-line | `#6A6A6A` | Ring around band controls | 3.88:1 vs band |
| sub | `#B3B3B3` | Secondary text, captions | 8.79:1 |
| mute | `#8A8A8A` | Borders, empty status ring | 5.34:1 |
| soft | `#262626` | Dropdown fields, disabled button | sub text 7.22:1 |
| hairline | `#2E2E2E` | Dividers | |
| bar | `#1C1C1C` | Bottom bar | sub text 8.13:1 |
| dialog | `#1F1F1F` | Dialog surface | white 16.48:1, radio ring 4.77:1 |
| primary button | white fill, black text | Inverted from light | 21:1 |
| ok | marker `#0E8345`, text `#2FB36A` | | 3.82:1 marker, 6.82:1 text |
| signal | `#FF6500`, text `#FF8A3D` | | 6.24:1, 7.86:1 |
| danger | `#FF9B9B` on `#3A1616` | | 7.97:1 |

Camera chrome (top controls, bottom deck) stays black in both themes. A colored frame around the viewfinder changes how technicians judge the photo's colors.

Color rules:
- Orange marks something that needs attention. A screen where nothing needs attention shows no orange.
- Status is never color only: every status pairs a marker shape and/or text (see Status markers).
- Core palette: ink, white, BSS blue, plus signal orange. Ok and danger are status semantics. Green markers on the blue band carry a white ring (green alone is 1.99:1 there).

## Typography

Figtree (Aan 2026-11-10: rounder, legible at small sizes, already bundled). Numbers use tabular figures. Scale reduced one step for mobile on 2026-11-09 (Aan: the first draft was too big; it pushed titles to two lines and made the band too tall).

| Role | 360dp | 390dp and up | Weight |
|---|---|---|---|
| Hero number in band | 32 | 36 | ExtraBold |
| Hero label next to number | 15 | 16 | Bold |
| Screen title (Detail Lokasi) | 20 | 22 | ExtraBold |
| Section heading | 16 | 16 | Bold |
| Row title | 15 / line 20 | 15 / line 20 | SemiBold |
| Meta line | 13 / line 18 | 13 / line 18 | Medium |
| Status line | 13 | 13 | Bold |
| Button | 14 | 14 | SemiBold |
| Bottom CTA, FAB | 16 | 16 | Bold |
| Caption | 12 to 13 | 12 to 13 | Medium / SemiBold |

Text scale: every height is intrinsic. At 200% system text size rows grow, the hero label wraps under the number, and the band grows with it. Titles never use `maxLines`.

## Shape, spacing, touch

- Buttons, chips, segmented controls: pill. Band cells (fase, stat tiles): radius 12. Dropdown fields: radius 0 with a 2px bottom rule (`body` light, `sub` dark), the input language. Dialogs 20, sheets 24 top corners, thumbnails 8.
- Screen padding 16 below 375dp wide, 20 from 375dp.
- Touch: every control is at least 44px visually with a 48dp hit area (`kMinInteractiveDimension`), with at least 8px between neighbours. Icon-only kebab and month arrows get an invisible 44 to 48 hit box.
- Elevation only on things that float: bottom bar, FAB, map controls, dialogs.

## Identity motif: the band

Every screen opens with a solid band (BSS blue in light, black in dark) holding the one number that matters on that screen: tasks done, photos in, locations by status, attendance count. A row of small perforation notches (8 to 10px circles in the body color) sits on the band's bottom edge, like a torn parking ticket. It is the only decoration and it repeats on every screen.

The band scrolls away with the content. A compact pinned bar (status inset + 56) keeps the title and the key number ("Daily Task · 1/4 selesai") so the header never takes a third of the screen. Flutter: `SliverAppBar(pinned: true)` with the band as the flexible space.

## Components

- **Band icon button**: 44 circle, band-raise fill, band-line ring, white icon. Icon-only is allowed only for platform glyphs: back, refresh, timer, flash, flip camera, map center and zoom, plus the camera location pin (Aan 2026-11-09). Each carries a semantic label (see layer names in the FigCraft file).
- **Band pill**: same colors with icon + text. Every non-obvious action is labelled: `Menu` (with pending badge), `Briefing`, `Rekap`, `Buka di Maps`, `Riwayat`, `Export CSV`.
- **Camera location button**: icon-only pin pill, 64x32 visual (Aan 2026-11-09) inside a 64x48 hit box, semantic label `Pilih lokasi realtime` (same as `camera_capture_screen.dart:2278`).
- **Camera controls**: top-right column = timer, flash, flip camera, ratio (`3:4` text, opens the existing ratio picker). Bottom deck = shift pill, then Galeri / shutter / Template. No zoom row: Aan dropped it on 2026-11-09 because technicians never use zoom; implementation removes the zoom buttons.
- **Row**: status marker, title, meta, status line, trailing action (44 pill), optional secondary action under the meta. Hairline divider inset to the text column.
- **Buttons**: primary = blue fill + white text (light) / white fill + black text (dark). Secondary = transparent with 1.5px blue border and blue text (light) or white border and text (dark). Disabled = soft fill, body text, action blocked. Content text stays black in light mode, so blue plus the pill shape always means tappable.
- **Segmented control**: only for a fixed set of up to 3 options (Semua / Pending / Selesai, Temuan / Checklist). Transparent track with mute border, selected segment blue (light) or white (dark).
- **Dropdown field + dialog**: for filters with a variable list or more than 3 options (Teknisi, Status checklist, Unit/Gate). Tapping opens a centered dialog with radio rows (52 high) and counts; selecting applies and closes; `Tutup`, scrim tap, Back, and Escape close it. This replaces every horizontal chip scroller (Aan 2026-11-09: no sideways scrolling).
- **Status markers (16px)**: ok = green circle with white check; attention = orange circle with ink ring and "!"; not started = hollow mute ring. The shape tells the state even without color.
- **Status chips**: `Sesuai` ok fill + white text, `Perlu cek` signal fill + black text, `Belum diperbaiki` soft + body text, `Urgent` danger tint.
- **Bottom bar**: 52 CTA, optional helper line ("6 poin belum difoto"), sits above the bottom safe-area inset.
- **FAB** (`Buat Tugas`): bottom right, 16 above the inset.
- **Map pin**: 32 circle with glyph (check / ! / minus) and a label pill; the pin plus its label form one 48x60 hit area. Tapping a pin opens Detail Lokasi directly (Aan 2026-11-04); a cluster opens the cluster sheet. Stat tiles `Belum / Temuan / Aman` filter the markers; the Temuan tile turns orange when its count is above 0.

## Layout across widths

- Floor target 360dp (Samsung A03, Redmi 9A, per `docs/design/daily_task_team_pma_spec.md:404`). Between 320 and 359 the 360 layout holds; rows wrap.
- 360 to 599dp: one full-width column.
- 600dp and up (tablet, web PWA): content column capped at 600 and centered. The band stays full-bleed with its contents aligned to the column. The bottom bar stays full-bleed with the CTA inside the column. The map stays full-bleed.
- No horizontal scrolling anywhere.
- Safe areas: content starts below the status inset. Bars and the FAB sit above the bottom inset (iOS home indicator 34, Android gesture area about 24). Scrolling lists get bottom padding equal to the bar height + 16, so the last row is always reachable.
- Forms in sheets scroll the focused field above the keyboard.

## States

Every data screen has three extra states, each with a cause and a next step:
- Empty: says why it is empty and offers the action that fills it ("Hari ini masih kosong" + `Catat Kerjaan baru`).
- Loading: says what is loading ("Memuat tugas hari ini"), no fake skeleton.
- Offline / error: orange marker, last update time, `Coba Lagi`. Map keeps its existing text "Offline, menampilkan data lokal · Update HH:mm".

## Interaction and accessibility

- Pressed: light primary `#1A428A` to `#143672` (white text 11.66:1), dark primary white to `#E2E2E2`. Web hover uses the same values with a click cursor.
- Focus ring: 2px ink on light surfaces, 2px white on dark surfaces and on the band, 2px offset. Never orange (2.95:1 on white).
- Every icon-only control has a semantic label. Images of people or places have descriptions; decorative perforation is excluded from semantics.
- Reduced motion (`MediaQuery.disableAnimations`): transitions become instant.

## Motion (MOTION 1)

Press feedback 100ms. Sheets and dialogs 220ms ease-out. Band collapse follows the scroll. No list fade-ups, no bounce, no looping animation.

## Copy

Button and screen labels are copied verbatim from the app (`Catat Kerjaan baru`, `Lihat Bukti`, `Lanjutkan`, `Belum Selesai`, `Kerjakan`, `Buat Tugas`, `Tandai Sudah Diperbaiki`, `Kirim ulang laporan WA`, `Simpan & Selesaikan Laporan`). New text (empty, loading, offline) is plain Indonesian with no em dash. Names and numbers in the mockups are sample data.
