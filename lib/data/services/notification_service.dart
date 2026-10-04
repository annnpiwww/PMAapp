import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'absensi_setup_service.dart';

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

  static const int notificationIdMasuk = 1001;
  static const int notificationIdPulang = 1002;
  static const int notificationIdReminderPulang = 2001;

  /// Inisialisasi konfigurasi notifikasi lokal dan timezone
  Future<void> init() async {
    if (_isInitialized) return;

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
    try {
      await _notificationsPlugin.cancel(id: notificationIdReminderPulang);
      debugPrint('[NotificationService] Pengingat jadwal pulang dibatalkan.');
    } catch (_) {}
  }
}
