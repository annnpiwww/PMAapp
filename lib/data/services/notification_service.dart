import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'absensi_setup_service.dart';
import '../models/daily_task_model.dart';

/// Service untuk menangani push / local notification absensi & pengingat jam shift kerja.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String _channelId = 'bss_absensi_channel';
  static const String _channelName = 'Absensi & Shift BSS';
  static const String _channelDesc =
      'Pengingat jam kerja shift dan konfirmasi absensi teknisi';

  static const String _dailyChannelId = 'bss_daily_tasks_channel';
  static const String _dailyChannelName = 'Daily Tasks BSS';
  static const String _dailyChannelDesc =
      'Pengingat dan status tugas harian teknisi BSS';

  static const String priorityTaskChannelId = 'bss_task_priority_channel';
  static const String _priorityTaskChannelId = priorityTaskChannelId;
  static const String _priorityTaskChannelName = 'Tugas Prioritas BSS';
  static const String _priorityTaskChannelDesc =
      'Notifikasi prioritas tinggi penugasan baru dari Supervisor';

  String? _lastDailyTasksSignature;
  DateTime? _lastDailyTasksNotifyTime;

  @visibleForTesting
  String? get lastDailyTasksSignature => _lastDailyTasksSignature;

  @visibleForTesting
  void resetDailyTasksSignatureForTesting() {
    _lastDailyTasksSignature = null;
    _lastDailyTasksNotifyTime = null;
  }

  static const int notificationIdMasuk = 1001;
  static const int notificationIdPulang = 1002;
  static const int notificationIdReminderPulang = 2001;
  static const int notificationIdDailyTasks = 3001;

  /// Inisialisasi konfigurasi notifikasi lokal dan timezone
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      // 1. Inisialisasi database timezone untuk penjadwalan tepat waktu
      tz.initializeTimeZones();

      // 2. Setting platform Android
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. Setting platform iOS/Darwin
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] Notifikasi ditekan: ${response.payload}');
        },
      );

      // 4. Buat notification channel Android dengan prioritas tinggi & suara
      final androidPlatform = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            _dailyChannelId,
            _dailyChannelName,
            description: _dailyChannelDesc,
            importance: Importance.defaultImportance,
            playSound: true,
            enableVibration: false,
          ),
        );

        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            _priorityTaskChannelId,
            _priorityTaskChannelName,
            description: _priorityTaskChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        // Permission notifikasi sudah diminta di _requestInitialPermissionsAndInit() secara sequential
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Notifikasi lokal berhasil diinisialisasi.');
    } catch (e, stack) {
      debugPrint('[NotificationService] Gagal inisialisasi: $e\n$stack');
    }
  }

  /// Notifikasi instan saat teknisi selesai absensi masuk:
  /// Contoh teks: "Absen masuk : Shift 2 (10:00 - 18:00)"
  Future<void> showInstantAbsenMasukNotification({
    required String shift,
  }) async {
    if (kIsWeb) return;
    await init();
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Absen Masuk Berhasil',
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF10B981),
      );

      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: notificationIdMasuk,
        title: 'Absen Masuk Berhasil',
        body: 'Absen masuk : $shift',
        notificationDetails: details,
      );
      debugPrint('[NotificationService] Notifikasi masuk terkirim: Absen masuk : $shift');
    } catch (e) {
      debugPrint('[NotificationService] Error kirim notifikasi masuk: $e');
    }
  }

  /// Menjadwalkan notifikasi realtime saat jam dinas/shift selesai:
  /// - Shift 2.2: 4 jam setelah check-in
  /// - Shift 1, 2, 3: 8 jam setelah check-in
  Future<void> scheduleAbsenPulangNotification({
    required String shift,
    required DateTime checkInTime,
  }) async {
    if (kIsWeb) return;
    await init();
    try {
      final scheduledPulang = AbsensiSetupService.getScheduledPulangTime(
        shift: shift,
        checkInTime: checkInTime,
      );
      final minDuration = AbsensiSetupService.getMinimumWorkDuration(shift);
      final durationTime = checkInTime.add(minDuration);
      // Notifikasi berbunyi saat jadwal shift berakhir atau durasi minimal terpenuhi (mana yang lebih awal)
      final targetTime = scheduledPulang.isBefore(durationTime) ? scheduledPulang : durationTime;

      final now = DateTime.now();
      if (!targetTime.isAfter(now)) {
        debugPrint('[NotificationService] Waktu shift sudah lewat, notifikasi jadwal di-skip');
        return;
      }

      final scheduledDate = tz.TZDateTime.from(targetTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFF59E0B),
      );

      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id: notificationIdReminderPulang,
        title: 'Waktunya Absensi Pulang! ⏰',
        body: 'Waktu kerja shift $shift telah selesai. Yuk isi daily dulu ya dan ambil foto kepulangan!',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint(
          '[NotificationService] Berhasil menjadwalkan notifikasi pulang pada: $targetTime ($scheduledDate)');
    } catch (e) {
      debugPrint('[NotificationService] Error penjadwalan notifikasi pulang: $e');
    }
  }

  /// Notifikasi instan saat teknisi selesai absensi pulang
  Future<void> showInstantAbsenPulangNotification({
    required String shift,
    String? durationText,
  }) async {
    if (kIsWeb) return;
    await init();
    try {
      await cancelAbsenPulangNotification();

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Absen Pulang Berhasil',
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF38BDF8),
      );

      const details = NotificationDetails(android: androidDetails);

      final durasiInfo = durationText != null && durationText.isNotEmpty
          ? ' (Durasi: $durationText)'
          : '';

      await _notificationsPlugin.show(
        id: notificationIdPulang,
        title: 'Absen Pulang Berhasil',
        body: 'Absen pulang : $shift$durasiInfo. Terima kasih atas kerja keras Anda hari ini!',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error kirim notifikasi pulang: $e');
    }
  }

  /// Membatalkan pengingat jadwal pulang (dipanggil saat teknisi sudah sukses absen pulang)
  Future<void> cancelAbsenPulangNotification() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: notificationIdReminderPulang);
      debugPrint('[NotificationService] Pengingat jadwal pulang dibatalkan.');
    } catch (_) {}
  }

  /// Notifikasi status Daily Task hari ini jika masih ada tugas yang pending
  Future<void> showDailyTasksNotification({
    required List<DailyTaskModel> tasks,
    bool force = false,
  }) async {
    if (kIsWeb) return;
    await init();
    try {
      final pending = tasks.where((t) => !t.isCompleted).toList();
      if (pending.isEmpty) {
        await cancelDailyTasksNotification();
        return;
      }

      // Hitung signature unik berbasis jumlah dan ID tugas yang pending
      final signature = '${pending.length}_${pending.map((t) => t.id).join(',')}';

      // Cegah spam: jika isi tugas belum berubah dan tidak dipaksa (force), abaikan pemanggilan ulang
      if (!force && signature == _lastDailyTasksSignature) {
        debugPrint('[NotificationService] Signature daily tasks identik ($signature), skip notifikasi redundan');
        return;
      }

      // Throttle: cegah pemanggilan bertubi-tubi dalam jeda singkat (< 5 detik)
      final now = DateTime.now();
      if (!force &&
          _lastDailyTasksNotifyTime != null &&
          now.difference(_lastDailyTasksNotifyTime!) < const Duration(seconds: 5)) {
        debugPrint('[NotificationService] Notifikasi daily tasks di-throttle (< 5s)');
        return;
      }

      _lastDailyTasksSignature = signature;
      _lastDailyTasksNotifyTime = now;

      final title = '📋 Daily Task Hari Ini (${pending.length} Tugas)';
      final lines = pending.take(4).map((t) => '• ${t.judul}').join('\n');
      final body = pending.length > 4 ? '$lines\n• ...dan ${pending.length - 4} tugas lainnya' : lines;

      const androidDetails = AndroidNotificationDetails(
        _dailyChannelId,
        _dailyChannelName,
        channelDescription: _dailyChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        onlyAlertOnce: true,
        ticker: 'Daily Task Pending',
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFF59E0B),
        styleInformation: BigTextStyleInformation(''),
      );

      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: notificationIdDailyTasks,
        title: title,
        body: body,
        notificationDetails: details,
        payload: 'daily_tasks',
      );
      debugPrint('[NotificationService] Notifikasi daily tasks terkirim: $title');
    } catch (e) {
      debugPrint('[NotificationService] Error kirim notifikasi daily tasks: $e');
    }
  }

  /// Membatalkan notifikasi daily tasks (misal saat semua tugas selesai)
  Future<void> cancelDailyTasksNotification() async {
    if (kIsWeb) return;
    try {
      _lastDailyTasksSignature = null;
      await _notificationsPlugin.cancel(id: notificationIdDailyTasks);
      debugPrint('[NotificationService] Notifikasi daily tasks dibatalkan.');
    } catch (_) {}
  }

  static const int notificationIdNewTask = 3002;

  /// Notifikasi instan saat SPV baru saja menugaskan pekerjaan baru (realtime pop-up heads-up)
  Future<void> showNewTaskAlertNotification({
    required String judul,
    required String posName,
    String? deskripsi,
  }) async {
    if (kIsWeb) return;
    await init();
    try {
      const androidDetails = AndroidNotificationDetails(
        _priorityTaskChannelId,
        _priorityTaskChannelName,
        channelDescription: _priorityTaskChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ticker: 'Tugas Baru dari SPV!',
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFFF6500),
        styleInformation: BigTextStyleInformation(''),
      );

      const details = NotificationDetails(android: androidDetails);

      final body = (deskripsi != null && deskripsi.isNotEmpty)
          ? 'Lokasi: $posName • $deskripsi'
          : 'Lokasi: $posName • Segera cek dan kerjakan ya!';

      await _notificationsPlugin.show(
        id: notificationIdNewTask,
        title: '🔔 Tugas Baru dari SPV: $judul',
        body: body,
        notificationDetails: details,
        payload: 'daily_tasks_new',
      );
      debugPrint('[NotificationService] Alert tugas baru SPV terkirim: $judul');
    } catch (e) {
      debugPrint('[NotificationService] Error kirim alert tugas baru: $e');
    }
  }
}
