# Implementation Plan: WhatsApp Share from History

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambahkan kemampuan membagikan laporan maintenance langsung dari halaman Riwayat (`HistoryListScreen`) ke WhatsApp secara instan dengan teks standar BSS Parking dan lampiran foto-foto checklist.

**Architecture:**
- Integrasikan `WhatsAppReportService.shareToWhatsApp` ke dalam widget kartu `ExpansionTile` di `HistoryListScreen`.
- Resolve `TemplateCategory` dari submission templateId / `TemplateRepository`.
- Tambahkan aksi share multi-file foto dan teks laporan.

## Global Constraints
- Target platform: Android.
- Orientation: Portrait only.
- Strict non-blocking UI.
- All tests must pass: `flutter test`.

---

### Task 1: Tambahkan Aksi WhatsApp Share pada HistoryListScreen
**Files:**
- Modify: `lib/features/history/screens/history_list_screen.dart:250-360`
- Test: `test/whatsapp_report_test.dart`

**Description:**
Tambahkan tombol *"Bagikan ke WhatsApp"* di dalam kartu riwayat maintenance (ExpansionTile) saat kartu dibuka, sehingga teknisi dapat langsung menekan tombol tersebut kapan saja dari tab Riwayat.

- [ ] **Step 1: Update `HistoryListScreen` dengan tombol Bagikan ke WhatsApp**
- [ ] **Step 2: Jalankan `flutter test` untuk verifikasi**
- [ ] **Step 3: Build APK debug dan install ke HP via ADB**
