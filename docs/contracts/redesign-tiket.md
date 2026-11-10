# Contract: PMA App redesign "Tiket"

Design source of truth: `docs/design/DESIGN.md` (tokens, contrast ratios, rules) and the FigCraft mockups in `docs/design/redesign-v3/` (`light-390-*.png`, `dark-390-*.png`, `00-*.png`). Flows, data, business logic, and button labels do not change.

## 1. Tokens (owner: coder, phase 1)

Add a `ThemeExtension<TiketColors>` in `lib/core/constants/tiket_colors.dart`, registered in both `AppTheme.lightTheme` and `AppTheme.darkTheme`. Widgets read `TiketColors.of(context)`. Never hardcode these hex values in screens.

| Field | Light | Dark |
|---|---|---|
| canvas | #FFFFFF | #141414 |
| ink (content text) | #000000 | #FFFFFF |
| body (secondary text) | #5E5E5E | #B3B3B3 |
| mute (borders, empty ring) | #8A8A8A | #8A8A8A |
| soft (fields, disabled) | #EFEFEF | #262626 |
| hairline | #E2E2E2 | #2E2E2E |
| bar (bottom bar) | #FFFFFF | #1C1C1C |
| dialog (sheet/dialog surface) | #FFFFFF | #1F1F1F |
| band | #1A428A | #000000 |
| bandRaise | #2A549C | #1F1F1F |
| bandLine | #8EA3D3 | #6A6A6A |
| bandCaption | #D3DDF2 | #B3B3B3 |
| bandTrack | #40649F | #3A3A3A |
| primary (tappable fill) | #1A428A | #FFFFFF |
| onPrimary | #FFFFFF | #000000 |
| primaryPressed | #143672 | #E2E2E2 |
| signal | #FF6500 | #FF6500 |
| signalText | #B34700 | #FF8A3D |
| ok (marker/chip fill) | #0E8345 | #0E8345 |
| okText | #0E8345 | #2FB36A |
| danger | #C81E1E | #FF9B9B |
| dangerTint | #FBE9E9 | #3A1616 |

Camera chrome stays black in both themes. Font: `Figtree` (Aan 2026-11-10: rounder, legible at small sizes), tabular figures for numbers.

Type scale (`TiketType`, widths below 375dp use the first value): hero 32/36 ExtraBold, heroLabel 15/16 Bold, screenTitle 20/22 ExtraBold, section 16 Bold, rowTitle 15 SemiBold (line 20), meta 13 Medium (line 18), status 13 Bold, button 14 SemiBold, cta 16 Bold, caption 12 Medium. Padding 16 below 375dp, 20 from 375dp.

## 2. Shared widgets (owner: coder, phase 1) in `lib/core/widgets/tiket/`

| Widget | API | Rules |
|---|---|---|
| `TiketBand` | `({Widget? leading, List<Widget> actions, String? caption, Widget? hero, Widget? footer})` | band color, perforation row (10px circles in canvas color, every 22px) on the bottom edge, content below status inset |
| `TiketSliverBand` | same + `String compactTitle` | `SliverAppBar(pinned)`: expanded = `TiketBand`, collapsed = band color bar (status inset + 56) with leading, compactTitle, actions |
| `TiketIconButton` | `({IconData icon, String semanticLabel, VoidCallback? onPressed})` | 44 circle bandRaise + 1.5px bandLine ring, white icon, 48 hit area, tooltip = semanticLabel |
| `TiketPill` | `({String label, IconData? icon, TiketPillKind kind, VoidCallback? onPressed, double height = 44, bool expand = false, String? badge})` | kinds: primary, secondary (transparent + 1.5px primary border + primary text), disabled (soft + body text), band (bandRaise + bandLine), bandSelected (white fill + ink text); min hit 48; pressed = primaryPressed |
| `StatusMarker` | `({TiketStatus status, double size = 16, bool onBand = false})` | ok = green + white check; attention = signal + 1.5 ink ring + "!"; notStarted = hollow 2px ring (mute, bandCaption when onBand); danger = danger fill + white "!"; ok onBand gets a 1.5 white outer ring; Semantics label per status |
| `StatusChip` | `({String label, TiketChipKind kind})` | ok = ok fill + white text, attention = signal + black text, neutral = soft + body, danger = dangerTint + danger text; 28 high, not tappable |
| `TiketRow` | `({Widget? leading, required String title, List<String> meta, (String, Color)? status, Widget? trailing, Widget? below, VoidCallback? onTap})` | title rowTitle wraps (no maxLines), hairline divider inset to text column |
| `TiketSegmented<T>` | `({List<(T, String)> options, T selected, ValueChanged<T> onChanged})` | max 3 options, 44 high, transparent track + 1.5 mute border, selected = primary fill + onPrimary text |
| `TiketDropdownField` | `({String label, String value, VoidCallback onTap})` | 52 high, soft fill, radius 0, 2px bottom rule (body color: #5E5E5E light, #B3B3B3 dark), chevron-down, opens a dialog |
| `showTiketPickerDialog<T>` | `({String title, String? subtitle, List<TiketOption<T>> options, T selected})` → `Future<T?>` | centered dialog radius 20, radio rows 52 high (label, optional trailing text + StatusMarker), `Tutup` secondary, closes on select / scrim / back |
| `TiketBottomBar` | `({required Widget primary, Widget? secondary, String? helper})` | bar color, top shadow, primary 52 high, secondary 48 stacked under it, respects bottom safe-area inset |

## 3. Build order and owners

1. Phase 1 (coder): tokens + theme + shared widgets + widget tests. No screen changes.
2. Phase 2 (after phase 1 approve, parallel, disjoint files): screen groups assigned by Mandor (camera group, daily task + SPV + arsip, map + detail + checklist + AI dialogs, remaining 14 daily-flow surfaces after Aan approves their mockups).
3. Phase 3 (qa): screenshots 360/390 light/dark vs mockups, full `flutter analyze` + `flutter test`.

## 4. Global acceptance

- No horizontal scrolling; every control ≥44 visual / 48 hit; text never clipped at textScaler 1.3; status never color only.
- Light and dark both match DESIGN.md tokens; no stray hex in screens.
- Labels verbatim from the current app; new copy without em/en dash.
- Drawer header keeps the current logo (Aan 2026-11-09): `Image.asset('foto/bssfotologo_transparent.png', height: 48, fit: BoxFit.contain)` centered on the band, no "BSS PARKING" text, no subtitle; keep the existing text errorBuilder. Mockup frame `15 Menu samping (teknisi)`.
- Login = concept A "Tiket" (Aan 2026-11-09): full band background, white ticket card (dark: `dialog` surface) holding a stub (logo `foto/splash_logo.png` 64 circle + title `PMApp` + `Absen, Maintenance & Daily Task`), a dashed perforation with two band-colored side notches, then the form. Title text changes from `PMA App` to `PMApp`; all other labels verbatim. Mockups `light-390-14-login.png`, `light-390-14b-login-salah-sandi.png`, `dark-390-14-login.png`.
