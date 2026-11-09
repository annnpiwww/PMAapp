# PMA App Redesign Concepts Specification

This document defines the 3 architectural design concepts created for the PMA (BssparkingTimeMark) mobile application. Each concept completely eliminates AI-slop card sprawl and card-in-card nesting, substituting them with distinct, intentional grouping paradigms.

---

## Concept A: "Grouped List" (iOS Systemic / Human Interface Paradigm)

### 1. Philosophy & Character
Inspired by Apple HIG System Settings and enterprise field utilities. Groups related information into flush or inset rounded containers on a tinted canvas. Eliminates drop shadows completely (`box-shadow: none`). Structure is maintained through clean padding rhythm, solid fills, and 0.5px hairline dividers.

### 2. Grouping Rule (Replacing Cards)
* Inset rectangular sections with rounded corners (`border-radius: 10px`) sitting on a soft background canvas (`#F2F2F7` light, `#000000` dark).
* Inside each group: clean vertical rows with uniform 48px min touch target height.
* Row structure: `[Leading Tinted Icon Box (28x28)]` + `[Label & Description]` + `[Trailing Value / Status Pill / Chevron]`.
* Separator: Sub-pixel hairline divider (`0.5px solid #C6C6C8` light, `#38383A` dark) inset 44px from left (aligns with text start).
* Section header: Small uppercase caption above the group (`12px, font-weight: 600, color: textSecondary, padding: 16px 16px 6px`).

### 3. Design Tokens
* **Typography Scale (min 12sp / 12px)**:
  * Title 1 (App Header): 20px / 700 / 1.2
  * Title 2 (Section Title): 16px / 700 / 1.25
  * Body (Standard Row): 14px / 600 / 1.35
  * Subheadline (Meta / Secondary): 12px / 500 / 1.3
  * Footnote / Badge: 12px / 700 / 1.0 (uppercase)
* **Spacing Scale**: 4px, 8px, 12px, 16px, 24px (strict 4/8/12/16/24 scale).
* **Radii Scale (Max 3 Radii)**:
  * `0px` (Dividers, full bleed edges)
  * `10px` (Grouped container boxes, input fields, image thumbnails)
  * `20px` (Status badges, pill buttons)
* **Elevation Scale (Max 2 Elevations)**:
  * `Elevation 0`: Flat `box-shadow: none` (Default for all surfaces)
  * `Elevation 1`: `0 2px 8px rgba(0,0,0,0.08)` (Reserved exclusively for bottom sheets/overlays)
* **Color Palette & Accent**:
  * Primary Accent: `#007AFF` (System Electric Blue) / `#1E448D` (Brand Deep Navy)
  * Success (Aman / Selesai): `#34C759` (Light) / `#30D158` (Dark)
  * Warning (Temuan / Perlu Cek): `#FF9500` (Light) / `#FF9F0A` (Dark)
  * Danger (Kritis / Urgent): `#FF3B30` (Light) / `#FF453A` (Dark)
* **Surfaces & Contrast (WCAG AA compliant >= 4.5:1)**:
  * *Light Mode*: Canvas `#F2F2F7`, Group Surface `#FFFFFF`, Text Primary `#000000` (Contrast 16.5:1), Text Secondary `#6C6C70` (Contrast 4.8:1), Divider `#C6C6C8`.
  * *Dark Mode*: Canvas `#000000`, Group Surface `#1C1C1E`, Text Primary `#FFFFFF` (Contrast 15.8:1), Text Secondary `#8E8E93` (Contrast 5.1:1), Divider `#38383A`.

---

## Concept B: "Ops Board" (Industrial Tactical / High-Density Operations)

### 1. Philosophy & Character
Built for rugged on-site efficiency. Full-bleed, edge-to-edge modularity designed for rapid glancing in harsh sunlight. Rather than floating cards, the screen is broken into distinct functional bands separated by 8dp background channels. Status is instantly recognizable via heavy 4px solid color rails on the left border of every data item.

### 2. Grouping Rule (Replacing Cards)
* Full-bleed panels (`border-radius: 0`) stretching the entire viewport width.
* Major sections are demarcated by 8dp neutral separation tracks (`background: #E2E8F0` light, `#0F172A` dark).
* High-density key-value data grids: 2-column or 4-column metric tables with clear monospace numerical values.
* Status presentation: A 4px thick vertical rail on the left edge (`border-left: 4px solid <color>`) accompanied by concrete uppercase status text.
* Sticky segmented operational header bands for instant filtering without visual clutter.

### 3. Design Tokens
* **Typography Scale (min 12sp / 12px)**:
  * Headline: 18px / 800 / 1.15 (letter-spacing: -0.2px)
  * Section Header: 14px / 700 / 1.2 (uppercase, letter-spacing: 0.5px)
  * Operational Row: 13px / 600 / 1.3
  * Numerical Metric: 16px / 800 / 1.0 (tabular figures)
  * Tactical Meta: 12px / 600 / 1.2
* **Spacing Scale**: 4px, 8px, 12px, 16px, 24px.
* **Radii Scale (Max 3 Radii)**:
  * `0px` (Full-bleed panels, section rails, dividers)
  * `4px` (Tactical buttons, inputs)
  * `6px` (Status badges, indicator tags)
* **Elevation Scale (Max 2 Elevations)**:
  * `Elevation 0`: Flat `box-shadow: none` with 1px border lines
  * `Elevation 1`: `0 -2px 6px rgba(0, 0, 0, 0.08)` (Reserved for sticky bottom execution bar)
* **Color Palette & Accent**:
  * Primary Accent: `#0F766E` (Tactical Deep Teal)
  * Operational Brand: `#1E3A8A` (Deep Marine)
  * Safe / Verified: `#059669` (Forest Green rail)
  * Attention / Temuan: `#D97706` (Amber Ochre rail)
  * Unchecked / Pending: `#475569` (Slate Grey rail)
* **Surfaces & Contrast (WCAG AA compliant >= 4.5:1)**:
  * *Light Mode*: Canvas `#F1F5F9`, Panel `#FFFFFF`, 8dp Track `#E2E8F0`, Text Primary `#0F172A` (Contrast 14.8:1), Text Secondary `#475569` (Contrast 6.2:1).
  * *Dark Mode*: Canvas `#0B1120`, Panel `#131C2E`, 8dp Track `#0F172A`, Text Primary `#F8FAFC` (Contrast 15.2:1), Text Secondary `#94A3B8` (Contrast 5.9:1).

---

## Concept C: "Bold Type" (Editorial Minimal / Typographic Hierarchy)

### 1. Philosophy & Character
Elevates scannability through typographic contrast and deliberate whitespace. Eliminates all card boundaries around list items. Instead of putting things inside boxes, typography carries the entire structure: oversized numerals, distinct weights, and clear section dividers. Exactly ONE hero surface is allowed per screen to anchor the visual weight.

### 2. Grouping Rule (Replacing Cards)
* Boxless layout: items are un-enclosed rows breathing with 16px–24px vertical padding.
* Exactly ONE Hero Surface per screen (e.g. big progress hero banner or camera viewfinder).
* Prominent numerical values (28px–36px font-weight 800) for fast cognitive absorption.
* Chronological or operational data uses a subtle vertical timeline axis line (`2px solid #E4E4E7` light, `#27272A` dark) connecting historical milestones.
* Inline primary actions (e.g., text button with arrow or minimal borderless CTA).

### 3. Design Tokens
* **Typography Scale (min 12sp / 12px)**:
  * Hero Value / Big KPI: 32px / 800 / 1.0 (letter-spacing: -0.5px)
  * Section Display: 18px / 800 / 1.2
  * Primary Title: 15px / 700 / 1.3
  * Body Item: 13px / 500 / 1.4
  * Micro Caption / Timestamp: 12px / 600 / 1.2
* **Spacing Scale**: 4px, 8px, 12px, 16px, 24px.
* **Radii Scale (Max 3 Radii)**:
  * `0px` (Hairline rules, vertical timeline stems)
  * `8px` (Hero banner surface, primary action buttons)
  * `16px` (Interactive filter chips, category pills)
* **Elevation Scale (Max 2 Elevations)**:
  * `Elevation 0`: Flat `box-shadow: none`
  * `Elevation 1`: `0 4px 12px rgba(15, 23, 42, 0.05)` (Hero surface only)
* **Color Palette & Accent**:
  * Primary Accent: `#2563EB` (Cobalt Royal Blue)
  * Positive / Done: `#16A34A`
  * Warning / Alert: `#EA580C`
  * Slate Stem / Line: `#E4E4E7` (Light) / `#27272A` (Dark)
* **Surfaces & Contrast (WCAG AA compliant >= 4.5:1)**:
  * *Light Mode*: Canvas `#FAF9F6` (Warm Off-white), Hero Surface `#FFFFFF`, Text Primary `#18181B` (Contrast 16.1:1), Text Secondary `#71717A` (Contrast 4.9:1).
  * *Dark Mode*: Canvas `#090D16` (Deep Obsidian), Hero Surface `#111827`, Text Primary `#F4F4F5` (Contrast 16.3:1), Text Secondary `#A1A1AA` (Contrast 5.4:1).

---

## Summary Matrix of Concepts

| Aspect | Concept A (Grouped List) | Concept B (Ops Board) | Concept C (Bold Type) |
|---|---|---|---|
| **Visual Metaphor** | iOS Settings Inset Group | Tactical Ops Rail Board | Editorial Typographic Timeline |
| **Separation Method** | 10px rounded inset blocks + hairline dividers | Full-bleed panels + 8dp neutral separation tracks | Generous whitespace + large heading scale + timeline |
| **Card Budget** | 0 elevated cards (100% flat inset surfaces) | 1 elevated surface max (sticky bottom execution bar) | 1 elevated surface max (Hero summary surface only) |
| **Status Coding** | Trailing colored pills & right-aligned icons | 4px solid left vertical color rail + uppercase text | Monospace inline status text + colored dot marker |
| **Touch Targets** | 48px standard row height | 44px dense tactical tap targets | 48px touch hitbox with generous padding |
| **Best Suited For** | High scannability, familiarity, elegant settings/lists | Harsh sunlight, rapid field status checks, data density | Executive summary, scannable tasks, timeline tracking |
