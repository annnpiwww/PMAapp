# Daily Task Reporting, Direct WhatsApp & Realtime Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengimplementasikan alur pelaporan Daily Task yang terpisah (per-task dokumentasi + notes langsung ke WhatsApp, dan macro summary text final daily saat tugas selesai), hard-gate validasi pengisian task, realtime badge angka pending di sidebar, dan notifikasi lokal Android harian.

**Architecture:** 
1. `DailyTaskService`: Menyediakan fungsi formatter laporan teks macro harian (`formatFinalDailyReport`) dan micro per-task (`formatPerTaskReport`).
2. `CustomTaskExecutionScreen`: Menerapkan validasi wajib foto & notes sebelum selesai, popup konfirmasi "Kirim Laporan" langsung buka WhatsApp via `ShareHelper.shareToWhatsApp`.
3. `TeknisiDailyTasksScreen`: Menyediakan sticky bottom summary bar "Kirim Laporan Daily Hari Ini" dengan teks ringkasan (hanya teks) langsung ke WhatsApp.
4. `CameraCaptureScreen` & `DailyTaskService`: Realtime `ValueNotifier<int>` untuk badge angka pending tasks di menu sidebar `Daily Task`.
5. `NotificationService`: Menambahkan fungsi `showDailyTasksNotification` untuk menampilkan notifikasi Android saat app dimuat / sync.

**Tech Stack:** Flutter / Dart, `flutter_local_notifications`, `ShareHelper` (Direct Intent WhatsApp), `PocketBase` REST API, Local Cache (`SharedPreferences`).

## Global Constraints
- **Scope Strict**: HANYA mengubah modul Daily Task. Modul Absensi dan Maintenance TETAP memiliki opsi WhatsApp dan Telegram.
- **Micro-report per task**: Format: `Dokumentasi: [Task Name]\nNotes: [Catatan]`.
- **Macro-report final**: Header, `Daftar list pekerjaan :` (tanpa kata 'Catatan :'), section `Pekerjaan Belum Selesai :` jika ada pending, dan section `Notes:`.
- **Hard Gate**: Dilarang klik Selesaikan Tugas jika foto == 0 ATAU catatan teknisi kosong.
- **Kualitas**: `flutter analyze` 0 issues, semua unit tests 100% pass.

---

### Task 1: Formatters di DailyTaskService & Unit Tests

**Files:**
- Modify: `lib/data/services/daily_task_service.dart`
- Test: `test/daily_task_formatters_test.dart`

**Interfaces:**
- Produces:
  - `DailyTaskService.formatPerTaskReport({required String judul, required String notes})` -> `String`
  - `DailyTaskService.formatFinalDailyReport({required String teknisiNama, required String tanggal, required String lokasi, String? posTag, required List<DailyTaskModel> completedTasks, required List<DailyTaskModel> pendingTasks, String? notes})` -> `String`
  - `DailyTaskService.pendingCountNotifier` -> `ValueNotifier<int>`
  - `DailyTaskService.updatePendingCount(int count)` -> `void`

- [ ] **Step 1: Write the failing unit test**

```dart
// test/daily_task_formatters_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/daily_task_model.dart';
import 'package:bssparking_timemark/data/services/daily_task_service.dart';

void main() {
  group('DailyTaskService Formatter Tests', () {
    test('formatPerTaskReport outputs Dokumentasi + Notes format', () {
      final res = DailyTaskService.formatPerTaskReport(
        judul: 'Backup server, hapus foto, upload cloud & HDD',
        notes: 'Selamat siang izin update backup server.',
      );
      expect(res, contains('Dokumentasi: Backup server, hapus foto, upload cloud & HDD'));
      expect(res, contains('Notes: Selamat siang izin update backup server.'));
      expect(res.contains('Laporan Daily Hari ini'), isFalse);
    });

    test('formatFinalDailyReport outputs macro report correctly when all completed', () {
      final task1 = DailyTaskModel(
        id: '1',
        tanggal: '2026-10-04',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Backup server, hapus foto, upload cloud & HDD',
        catatanTeknisi: 'Selamat siang izin update backup server.',
        jamSelesai: '11:30 WITA',
        status: 'completed',
      );
      final task2 = DailyTaskModel(
        id: '2',
        tanggal: '2026-10-04',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Pengecatan markah panah',
        catatanTeknisi: 'Markah panah gate masuk selesai dicat ulang.',
        jamSelesai: '14:15 WITA',
        status: 'completed',
      );

      final res = DailyTaskService.formatFinalDailyReport(
        teknisiNama: 'Raldy',
        tanggal: '2026-10-04',
        lokasi: 'Parkir Mall Manado',
        posTag: 'PBM',
        completedTasks: [task1, task2],
        pendingTasks: [],
        notes: '-',
      );

      expect(res, contains('Laporan Daily Hari ini'));
      expect(res, contains('Teknisi : Raldy'));
      expect(res, contains('Lokasi : PBM'));
      expect(res, contains('Daftar list pekerjaan :'));
      expect(res, contains('1. Backup server, hapus foto, upload cloud & HDD (Selesai 11:30 WITA)'));
      expect(res, contains('   Selamat siang izin update backup server.'));
      expect(res, contains('2. Pengecatan markah panah (Selesai 14:15 WITA)'));
      expect(res, contains('   Markah panah gate masuk selesai dicat ulang.'));
      expect(res, contains('Status : 2 Selesai, 0 Pending'));
      expect(res, contains('Notes:\n-'));
      expect(res.contains('Pekerjaan Belum Selesai :'), isFalse);
    });

    test('formatFinalDailyReport includes pending section when tasks remain incomplete', () {
      final task1 = DailyTaskModel(
        id: '1',
        tanggal: '2026-10-04',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Backup server',
        catatanTeknisi: 'Done',
        jamSelesai: '11:00 WITA',
        status: 'completed',
      );
      final pendingTask = DailyTaskModel(
        id: '2',
        tanggal: '2026-10-04',
        teknisiNama: 'Raldy',
        posName: 'Parkir Mall Manado',
        posTag: 'PBM',
        judul: 'Pengecekan sensor loop gate keluar',
        status: 'pending',
      );

      final res = DailyTaskService.formatFinalDailyReport(
        teknisiNama: 'Raldy',
        tanggal: '2026-10-04',
        lokasi: 'Parkir Mall Manado',
        posTag: 'PBM',
        completedTasks: [task1],
        pendingTasks: [pendingTask],
      );

      expect(res, contains('Pekerjaan Belum Selesai :'));
      expect(res, contains('- Pengecekan sensor loop gate keluar (Pending)'));
      expect(res, contains('Status : 1 Selesai, 1 Pending'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/daily_task_formatters_test.dart`
Expected: FAIL with undefined method formatPerTaskReport / formatFinalDailyReport.

- [ ] **Step 3: Implement functions in DailyTaskService**

Add `formatPerTaskReport`, `formatFinalDailyReport`, and `pendingCountNotifier` to `lib/data/services/daily_task_service.dart`:
```dart
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  static void updatePendingCount(int count) {
    if (pendingCountNotifier.value != count) {
      pendingCountNotifier.value = count;
    }
  }

  static String formatPerTaskReport({
    required String judul,
    required String notes,
  }) {
    final cleanNotes = notes.trim().isNotEmpty ? notes.trim() : '-';
    return '''Dokumentasi: ${judul.trim()}
Notes: $cleanNotes''';
  }

  static String formatFinalDailyReport({
    required String teknisiNama,
    required String tanggal,
    required String lokasi,
    String? posTag,
    required List<DailyTaskModel> completedTasks,
    required List<DailyTaskModel> pendingTasks,
    String? notes,
  }) {
    final tglIndo = _formatTanggalIndo(tanggal);
    final tagLokasi = _resolveTag(lokasi, posTag);

    final sb = StringBuffer();
    sb.writeln('Laporan Daily Hari ini');
    sb.writeln('Teknisi : ${teknisiNama.trim()}');
    sb.writeln('Tanggal : $tglIndo');
    sb.writeln('Lokasi : $tagLokasi');
    sb.writeln('');
    sb.writeln('Daftar list pekerjaan :');

    if (completedTasks.isEmpty) {
      sb.writeln('(Belum ada pekerjaan yang diselesaikan)');
    } else {
      for (int i = 0; i < completedTasks.length; i++) {
        final t = completedTasks[i];
        final jam = (t.jamSelesai != null && t.jamSelesai!.isNotEmpty) ? t.jamSelesai! : 'Selesai';
        sb.writeln('${i + 1}. ${t.judul} (Selesai $jam)');
        if (t.catatanTeknisi != null && t.catatanTeknisi!.trim().isNotEmpty) {
          sb.writeln('   ${t.catatanTeknisi!.trim()}');
        }
      }
    }

    if (pendingTasks.isNotEmpty) {
      sb.writeln('');
      sb.writeln('Pekerjaan Belum Selesai :');
      for (final p in pendingTasks) {
        sb.writeln('- ${p.judul} (Pending)');
      }
    }

    sb.writeln('');
    sb.writeln('Status : ${completedTasks.length} Selesai, ${pendingTasks.length} Pending');
    sb.writeln('-----');
    sb.writeln('Notes:');
    sb.write((notes != null && notes.trim().isNotEmpty) ? notes.trim() : '-');

    return sb.toString();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/daily_task_formatters_test.dart`
Expected: PASS all 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/data/services/daily_task_service.dart test/daily_task_formatters_test.dart
git commit -m "feat(daily_tasks): add formatters and pending count notifier"
```

---

### Task 2: Hard-Gate Validation & Direct WhatsApp di CustomTaskExecutionScreen

**Files:**
- Modify: `lib/features/daily_tasks/screens/custom_task_execution_screen.dart`

**Interfaces:**
- Consumes: `DailyTaskService.formatPerTaskReport`, `ShareHelper.shareToWhatsApp`
- Validasi: `_localPhotoPaths.isNotEmpty` DAN `_catatanCtrl.text.trim().isNotEmpty`

- [ ] **Step 1: Update UI and Validation in CustomTaskExecutionScreen**

Di `lib/features/daily_tasks/screens/custom_task_execution_screen.dart`:
1. Validasi di `_submitTask()`:
   ```dart
   if (_localPhotoPaths.isEmpty) {
     HapticFeedback.heavyImpact();
     setState(() {
       _errorMessage = 'Wajib mengambil minimal 1 foto dokumentasi!';
     });
     return;
   }
   if (catatan.isEmpty) {
     HapticFeedback.heavyImpact();
     setState(() {
       _errorMessage = 'Wajib mengisi catatan laporan teknisi!';
     });
     return;
   }
   ```
2. Disable state / Visual indicator pada tombol "Selesaikan Tugas" jika foto kosong atau catatan kosong.
3. Update modal `_showPostSaveDialog`:
   - Ganti isi format menjadi `DailyTaskService.formatPerTaskReport(judul: widget.task.judul, notes: catatan)`.
   - Ganti tombol pilihan "WhatsApp / Telegram" menjadi SATU tombol utama:
     **"Kirim Laporan"** (Background Hijau WhatsApp `#25D366`, Icon WhatsApp / Send) yang langsung memanggil:
     ```dart
     ShareHelper.shareToWhatsApp(
       text: reportText,
       imagePaths: _localPhotoPaths,
     );
     ```
   - Tombol kedua: **"Selesai (Nanti Saja)"** yang menutup dialog dan kembali ke list tugas.

- [ ] **Step 2: Run flutter analyze to ensure 0 syntax issues**

Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add lib/features/daily_tasks/screens/custom_task_execution_screen.dart
git commit -m "feat(daily_tasks): enforce hard-gate validation and direct whatsapp micro-report"
```

---

### Task 3: Sticky Bottom Bar "Kirim Laporan Daily Hari Ini" di TeknisiDailyTasksScreen

**Files:**
- Modify: `lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart`

**Interfaces:**
- Consumes: `DailyTaskService.formatFinalDailyReport`, `ShareHelper.shareToWhatsApp`

- [ ] **Step 1: Add Final Daily Report Button & Dialog in TeknisiDailyTasksScreen**

Di `lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart`:
1. Hitung status tugas hari ini:
   ```dart
   final completedTasks = _tasks.where((t) => t.isCompleted).toList();
   final pendingTasks = _tasks.where((t) => !t.isCompleted).toList();
   final allCompleted = _tasks.isNotEmpty && pendingTasks.isEmpty;
   ```
2. Update notifier pending count:
   ```dart
   DailyTaskService.updatePendingCount(pendingTasks.length);
   ```
3. Tambahkan BottomNavigationBar / Floating persistent action bar:
   - Jika `_tasks.isNotEmpty`:
     - Tombol: **"Kirim Laporan Daily Hari Ini"**
     - Subtitle/Badge status: `allCompleted ? "Semua Selesai (Centang Hijau)" : "${completedTasks.length}/${_tasks.length} Selesai"`.
     - Warna: Jika `allCompleted` $\rightarrow$ Hijau cerah (`#16A34A` / `#25D366`), jika belum $\rightarrow$ Dark / Secondary Accent.
4. Ketika tombol diklik:
   - Generate teks:
     ```dart
     final reportText = DailyTaskService.formatFinalDailyReport(
       teknisiNama: widget.teknisiNama,
       tanggal: widget.tanggal,
       lokasi: _tasks.first.posName,
       posTag: _tasks.first.posTag,
       completedTasks: completedTasks,
       pendingTasks: pendingTasks,
     );
     ```
   - Tampilkan preview modal teks dengan tombol **"Kirim Laporan"** yang langsung memanggil `ShareHelper.shareToWhatsApp(text: reportText)`. (Hanya teks sesuai spesifikasi).

- [ ] **Step 2: Run flutter analyze and tests**

Run: `flutter analyze && flutter test`
Expected: 0 issues, All tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/daily_tasks/screens/teknisi_daily_tasks_screen.dart
git commit -m "feat(daily_tasks): add final daily report macro summary direct to whatsapp"
```

---

### Task 4: Realtime Badge di Sidebar Drawer (CameraCaptureScreen)

**Files:**
- Modify: `lib/features/camera/screens/camera_capture_screen.dart`

**Interfaces:**
- Consumes: `DailyTaskService.pendingCountNotifier`

- [ ] **Step 1: Wrap Daily Task Drawer Item with ValueListenableBuilder**

Di `lib/features/camera/screens/camera_capture_screen.dart` pada menu item `Daily Task` (sekitar baris 3150-3180):
1. Wrap trailing widget dengan:
   ```dart
   ValueListenableBuilder<int>(
     valueListenable: DailyTaskService.pendingCountNotifier,
     builder: (context, pendingCount, _) {
       if (pendingCount > 0) {
         return Container(
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
           decoration: BoxDecoration(
             color: const Color(0xFFEF4444), // Oranye/Merah terang
             borderRadius: BorderRadius.circular(12),
           ),
           child: Text(
             '$pendingCount',
             style: const TextStyle(
               color: Colors.white,
               fontSize: 11,
               fontWeight: FontWeight.w800,
             ),
           ),
         );
       }
       return const Icon(Icons.chevron_right_rounded, size: 20);
     },
   )
   ```
2. Saat screen capture dimuat (`initState` atau resume), panggil `DailyTaskService.getTasksForTeknisi` di background untuk meng-update `pendingCountNotifier`.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/camera/screens/camera_capture_screen.dart
git commit -m "feat(camera): add realtime pending badge in drawer for daily tasks"
```

---

### Task 5: Android Local Notification Realtime (NotificationService)

**Files:**
- Modify: `lib/data/services/notification_service.dart`
- Modify: `lib/features/camera/screens/camera_capture_screen.dart` / `teknisi_daily_tasks_screen.dart`

**Interfaces:**
- Produces: `NotificationService.instance.showDailyTasksNotification(List<DailyTaskModel> tasks)`

- [ ] **Step 1: Add showDailyTasksNotification in NotificationService**

Tambahkan method di `NotificationService`:
```dart
  static const int notificationIdDailyTasks = 3001;

  Future<void> showDailyTasksNotification({
    required List<DailyTaskModel> tasks,
  }) async {
    if (tasks.isEmpty) return;

    final pending = tasks.where((t) => !t.isCompleted).toList();
    if (pending.isEmpty) return;

    final title = '📋 Daily Task Hari Ini (${pending.length} Tugas)';
    final lines = pending.take(4).map((t) => '• ${t.judul}').join('\n');
    final body = pending.length > 4 ? '$lines\n• ...dan ${pending.length - 4} tugas lainnya' : lines;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    await _notificationsPlugin.show(
      notificationIdDailyTasks,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'daily_tasks',
    );
  }
```

- [ ] **Step 2: Trigger Notification saat Fetch Tasks**

Panggil `NotificationService.instance.showDailyTasksNotification(tasks: list)` saat tasks berhasil dimuat di background atau saat teknisi membuka aplikasi.

- [ ] **Step 3: Run flutter analyze & test**

Run: `flutter analyze && flutter test`
Expected: No issues found! All tests passed!

- [ ] **Step 4: Commit**

```bash
git add lib/data/services/notification_service.dart
git commit -m "feat(notification): add android local notification for daily tasks"
```

---

### Task 6: Verifikasi Akhir, Build Rilis APK & Telegram Notification

- [ ] **Step 1: Run comprehensive tests & static analysis**
  - `flutter analyze`
  - `flutter test`
- [ ] **Step 2: Build release APK split-per-abi**
  - `flutter build apk --release --split-per-abi`
- [ ] **Step 3: Kirim notifikasi bot Telegram**
  - `anpidhs-notify -m "🚀 *[PMA App]* Daily Task Reporting & Realtime Notifications Updated!"`
- [ ] **Step 4: Update Obsidian Memory Vault**
  - Catat log perubahan di `Memory/Changelog/`.
