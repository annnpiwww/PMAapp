import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/data/models/maintenance_submission.dart';
import 'package:bssparking_timemark/data/models/template_model.dart';
import 'package:bssparking_timemark/data/services/whatsapp_report_service.dart';

void main() {
  group('WhatsAppReportService Tests', () {
    test('Generate Barrier Gate WhatsApp Report format correctly with clean natural notes', () {
      final submission = MaintenanceSubmission(
        id: 'test_1',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate & Sensor',
        userId: 'user_1',
        userName: 'Ryan Lumasuge',
        userNpp: '12345',
        posId: 'pos_nbm',
        posName: 'NBM',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'bar_1_01',
            label: 'Barrier Gate 1 - Dudukan Mesin & Baut Dinabolt',
            status: PointStatus.sesuai,
            alasan: '',
          ),
          const MaintenancePointResult(
            pointId: 'bar_1_02',
            label: 'Barrier Gate 1 - Fisik Palang Tertutup (0° Lurus)',
            status: PointStatus.tidakSesuai,
            alasan: 'Palang sedikit miring 5 derajat',
          ),
        ],
        createdAt: DateTime(2026, 8, 21, 9, 30),
        updatedAt: DateTime(2026, 8, 21, 10, 0),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintBarrier,
      );

      expect(text.contains('Selamat Pagi'), isTrue);
      expect(text.contains('Ryan Lumasuge'), isTrue);
      expect(text.contains('IT Support'), isTrue);
      expect(text.contains('Lokasi :'), isTrue);
      expect(text.contains('NBM'), isTrue);
      expect(text.contains('21 Agustus 2026'), isTrue);
      expect(text.contains('Note'), isTrue);
      expect(text.contains('Terima kasih 🙏'), isTrue);
      // Grouped format: should contain 9 points 1:1 with ✅/⚠️
      expect(text.contains('dudukan mesin & Baut dynabolt'), isTrue);
      expect(text.contains('fisik palang tertutup lurus'), isTrue);
      expect(text.contains('sensor loop detector'), isTrue);
    });

    test('Barrier Gate 10 units collapses 90 points into 9 grouped notes', () {
      // Simulate 10 gates x 9 points = 90 points, majority sesuai except a few
      final points = <MaintenancePointResult>[];
      for (int gate = 1; gate <= 10; gate++) {
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_01', label: 'Barrier Gate $gate - Dudukan Mesin & Baut Dynabolt', status: PointStatus.sesuai));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_02', label: 'Barrier Gate $gate - Fisik Palang Tertutup Lurus', status: gate == 4 ? PointStatus.tidakSesuai : PointStatus.sesuai, alasan: gate == 4 ? 'belum ada stiker' : ''));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_03', label: 'Barrier Gate $gate - Fisik Palang Terbuka', status: PointStatus.sesuai));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_04', label: 'Barrier Gate $gate - Pelumas (Spring/Bearing)', status: PointStatus.sesuai));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_05', label: 'Barrier Gate $gate - Sensor Loop Detector', status: PointStatus.sesuai));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_06', label: 'Barrier Gate $gate - Jalur Kabel Sensor', status: PointStatus.sesuai));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_07', label: 'Barrier Gate $gate - Stiker Receiver Barrier Gate', status: gate == 4 ? PointStatus.tidakSesuai : PointStatus.sesuai, alasan: gate == 4 ? 'stiker robek' : ''));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_08', label: 'Barrier Gate $gate - Tiang CCTV & Housing', status: PointStatus.sesuai));
        points.add(MaintenancePointResult(pointId: 'bar_${gate}_09', label: 'Barrier Gate $gate - Speedbump Gate', status: gate == 2 ? PointStatus.tidakSesuai : PointStatus.sesuai, alasan: gate == 2 ? 'baut terlepas' : ''));
      }
      final submission = MaintenanceSubmission(
        id: 'test_10gate',
        templateId: 'tpl_maint_barrier',
        templateName: 'Maintenance: Barrier Gate',
        userId: 'user_1',
        userName: 'Raldy sangkop',
        userNpp: '12345',
        posId: 'pos_pbm',
        posName: 'PBM',
        cabangName: 'Manado',
        points: points,
        createdAt: DateTime(2026, 8, 19, 13, 0),
        updatedAt: DateTime(2026, 8, 19, 14, 0),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintBarrier,
      );

      expect(text.contains('Selamat Siang'), isTrue);
      expect(text.contains('Lokasi : PBM'), isTrue);
      expect(text.contains('IT Support : Raldy sangkop'), isTrue);
      expect(text.contains('19 Agustus 2026'), isTrue);
      // Must be 9 line numbers (now 2 lines per note: label + icon line)
      final noteLines = text.split('\n').where((l) => RegExp(r'^\d+\.').hasMatch(l.trim())).toList();
      expect(noteLines.length, 9);
      // Should contain 2-line format: label then icon on next line
      expect(text.contains('*dudukan mesin & Baut dynabolt* :'), isTrue);
      expect(text.contains('*fisik palang tertutup lurus* :'), isTrue);
      expect(text.contains('tiang cctv & Housing'), isTrue);
      expect(text.contains('sensor loop detector'), isTrue);
      expect(text.contains('Terima kasih 🙏'), isTrue);
    });

    test('Generate Pos Kasir WhatsApp Report format correctly with clean natural notes', () {
      final submission = MaintenanceSubmission(
        id: 'test_2',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Kasir Parkir',
        userId: 'user_1',
        userName: 'Ryan Lumasuge',
        userNpp: '12345',
        posId: 'pos_pbm',
        posName: 'PBM',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pos Kasir 1 - Pembersihan Total Printer Pos',
            status: PointStatus.sesuai,
            alasan: '',
          ),
        ],
        createdAt: DateTime(2026, 8, 10, 20, 0),
        updatedAt: DateTime(2026, 8, 10, 20, 30),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintPos,
        unitCount: 6,
        gateOutNotes: '2, 3, 5',
      );

      expect(text.contains('Selamat Malam'), isTrue);
      expect(text.contains('Ryan Lumasuge'), isTrue);
      expect(text.contains('PBM'), isTrue);
      expect(text.contains('Gate Out'), isTrue);
      expect(text.contains('10 Agustus 2026'), isTrue);
      expect(text.contains('Terima kasih 🙏'), isTrue);
    });

    test('Pos Kasir report uses ✅ for points that are sesuai, not ⚠️ even when alasan has text', () {
      final submission = MaintenanceSubmission(
        id: 'test_pos_passed_points',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Parkir',
        userId: 'user_1',
        userName: 'Farhan Lakoro',
        userNpp: '12345',
        posId: 'pos_pbm',
        posName: 'Pasar Bersehati Manado (PBM)',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pos Kasir 1 - Pembersihan Total Printer Pos',
            status: PointStatus.sesuai,
            alasan: 'Printer pos sudah dibersihkan, head dan area kertas bersih dari sisa debu',
          ),
          const MaintenancePointResult(
            pointId: 'pos_1_02',
            label: 'Pos Kasir 1 - Kerapian Jalur Kabel & Stopkontak',
            status: PointStatus.sesuai,
            alasan: 'Kabel sudah dirapikan menggunakan Spiral Flexibel dan adaptor terpasang kencang',
          ),
          const MaintenancePointResult(
            pointId: 'pos_1_03',
            label: 'Pos Kasir 1 - Kelengkapan Meja Pos',
            status: PointStatus.sesuai,
            alasan: 'Meja pos sudah dirapikan, perangkat dan kipas angin tertata bersih tanpa barang pribadi',
          ),
          const MaintenancePointResult(
            pointId: 'pos_1_04',
            label: 'Pos Kasir 1 - Fungsi Sistem Layar Kasir Ready',
            status: PointStatus.sesuai,
            alasan: 'Layar kasir sudah ready dan aplikasi online siap melayani transaksi parkir',
          ),
          const MaintenancePointResult(
            pointId: 'pos_1_05',
            label: 'Pos Kasir 1 - Kunci Pintu Pos (Grendel Pintu)',
            status: PointStatus.tidakSesuai,
            alasan: 'Grendel pintu pos belum diperbaiki, baut longgar',
          ),
        ],
        createdAt: DateTime(2026, 9, 7, 16, 0),
        updatedAt: DateTime(2026, 9, 7, 16, 30),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintPos,
      );

      // Points 1, 2, 3, 4 MUST be ✅
      expect(text.contains('1. *Pembersihan total printer pos* :\n   ✅'), isTrue);
      expect(text.contains('2. *Kerapian jalur kabel & stopkontak* :\n   ✅'), isTrue);
      expect(text.contains('3. *Standarisasi item dalam pos* :\n   ✅'), isTrue);
      expect(text.contains('4. *Fungsi sistem aplikasi kasir* :\n   ✅'), isTrue);

      // Point 5 has issue, MUST be ⚠️
      expect(text.contains('5. *Kunci pintu pos (grendel pintu)* :\n   ⚠️'), isTrue);

      // HASIL MAINTENANCE summary check
      expect(text.contains('HASIL MAINTENANCE :'), isTrue);
      expect(text.contains('✅ Sesuai: 4'), isTrue);
      expect(text.contains('⚠️ Tidak Sesuai: 1'), isTrue);
      // 'Perlu Dicek' is 0, so it MUST NOT be displayed!
      expect(text.contains('Perlu Dicek'), isFalse);
      expect(text.contains('Total Point: 5'), isTrue);
    });

    test('Teknisi auto shift & greeting logic tests based on hour & return time', () {
      // Shift 1: 03:00 - 11:00 (Pagi)
      final timeShift1 = DateTime(2026, 9, 7, 8, 30);
      expect(WhatsAppReportService.getGreeting(timeShift1), 'Selamat Pagi');

      // Shift 2: 11:00 - 18:00 (Siang)
      final timeShift2 = DateTime(2026, 9, 7, 11, 15);
      expect(WhatsAppReportService.getGreeting(timeShift2), 'Selamat Siang');

      // Shift 3: 14:00 - 22:00 (Sore)
      final timeShift3 = DateTime(2026, 9, 7, 15, 30);
      expect(WhatsAppReportService.getGreeting(timeShift3), 'Selamat Sore');

      // Malam: 18:00++ / 22:00
      final timeMalam = DateTime(2026, 9, 7, 18, 0);
      expect(WhatsAppReportService.getGreeting(timeMalam), 'Selamat Malam');

      // Greeting dari jam pulang:
      expect(WhatsAppReportService.getGreetingFromTimeString('11:00'), 'Selamat Siang');
      expect(WhatsAppReportService.getGreetingFromTimeString('18:00'), 'Selamat Malam');
      expect(WhatsAppReportService.getGreetingFromTimeString('22:00'), 'Selamat Malam');
    });

    test('Technician name synchronization check', () {
      final submission = MaintenanceSubmission(
        id: 'test_sync_name',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Parkir',
        userId: 'user_1',
        userName: 'Ryan Lumasuge',
        userNpp: '12345',
        posId: 'pos_pbm',
        posName: 'Pasar Bersehati Manado (PBM)',
        cabangName: 'Manado',
        points: const [],
        createdAt: DateTime(2026, 9, 8, 10, 0),
        updatedAt: DateTime(2026, 9, 8, 10, 30),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintPos,
      );

      expect(text.contains('IT Support : Ryan Lumasuge'), isTrue);
      expect(text.contains('Farhan Lakoro'), isFalse);
    });

    test('Single unit reports show AI vision validation alasan on ✅ without Pos 1 prefix', () {
      final submission = MaintenanceSubmission(
        id: 'test_single_unit_ai',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Kasir',
        userId: 'user_1',
        userName: 'Junifer Manua',
        userNpp: '12345',
        posId: 'pos_1',
        posName: 'Pos 1',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'pos_1_01',
            label: 'Pos 1 - Pembersihan Total Printer Pos',
            status: PointStatus.sesuai,
            alasan: 'roller bersih bebas debu',
          ),
          const MaintenancePointResult(
            pointId: 'pos_1_05',
            label: 'Pos 1 - Kunci Pintu Pos (Grendel Pintu)',
            status: PointStatus.tidakSesuai,
            alasan: 'grendel pintu macet perlu pelumasan',
          ),
        ],
        createdAt: DateTime(2026, 9, 11, 8, 30),
        updatedAt: DateTime(2026, 9, 11, 9, 0),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintPos,
        unitCount: 1,
      );

      // Poin 1: AI Vision alasan displayed on green checkmark
      expect(text.contains('1. *Pembersihan total printer pos* :\n   ✅ roller bersih bebas debu'), isTrue);

      // Poin 2: Single unit does NOT contain 'Pos 1:' prefix
      expect(text.contains('Pos 1:'), isFalse);
      expect(text.contains('5. *Kunci pintu pos (grendel pintu)* :\n   ⚠️ grendel pintu macet perlu pelumasan'), isTrue);
    });

    test('Single unit server maintenance shows drive/temp AI vision validation reason', () {
      final submission = MaintenanceSubmission(
        id: 'test_single_server_ai',
        templateId: 'tpl_maint_server',
        templateName: 'Maintenance: Server & Kasir',
        userId: 'user_1',
        userName: 'Alessandro Sulistyo',
        userNpp: '12345',
        posId: 'server_1',
        posName: 'Server Utama',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'srv_01',
            label: 'Server - Pembersihan storage & file temp',
            status: PointStatus.sesuai,
            alasan: 'sisa 45GB drive C',
          ),
        ],
        createdAt: DateTime(2026, 9, 11, 10, 0),
        updatedAt: DateTime(2026, 9, 11, 10, 30),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintServer,
      );

      expect(text.contains('1. *Pembersihan storage & file temp* :\n   ✅ sisa 45GB drive C'), isTrue);
      expect(text.contains('Server:'), isFalse);
    });

    test('Multi-unit reports separate ok and problem units with unit prefix', () {
      final submission = MaintenanceSubmission(
        id: 'test_multi_pos',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Kasir',
        userId: 'user_1',
        userName: 'Ryan Lumasuge',
        userNpp: '12345',
        posId: 'pos_nbm',
        posName: 'NBM',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'p1_01',
            label: 'Pos 1 - Pembersihan Total Printer Pos',
            status: PointStatus.sesuai,
            alasan: 'roller bersih bebas debu',
          ),
          const MaintenancePointResult(
            pointId: 'p2_01',
            label: 'Pos 2 - Pembersihan Total Printer Pos',
            status: PointStatus.tidakSesuai,
            alasan: 'roller kotor banyak serbuk kertas',
          ),
        ],
        createdAt: DateTime(2026, 9, 11, 11, 30),
        updatedAt: DateTime(2026, 9, 11, 12, 0),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintPos,
        unitCount: 2,
      );

      // Multi-unit separates Pos 1 and Pos 2
      expect(text.contains('1. *Pembersihan total printer pos* :'), isTrue);
      expect(text.contains('✅ Pos 1: roller bersih bebas debu'), isTrue);
      expect(text.contains('⚠️ Pos 2: roller kotor banyak serbuk kertas'), isTrue);
    });

    test('Permanent locations auto-tag formatting in report', () {
      final sub1 = MaintenanceSubmission(
        id: 'test_pkm',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Kasir',
        userId: 'user_1',
        userName: 'Farhan Lakoro',
        userNpp: '12345',
        posId: 'pos_pkm',
        posName: 'Pelabuhan Kalimas Manado',
        cabangName: 'KC BSG',
        points: [
          const MaintenancePointResult(
            pointId: 'p1',
            label: 'Pembersihan total printer pos',
            status: PointStatus.sesuai,
          ),
        ],
        createdAt: DateTime(2026, 9, 13, 10, 0),
        updatedAt: DateTime(2026, 9, 13, 10, 30),
      );
      final text1 = WhatsAppReportService.generateReportText(
        submission: sub1,
        category: TemplateCategory.maintPos,
      );
      expect(text1.contains('Lokasi : Pelabuhan Kalimas Manado (PKM)'), isTrue);

      final sub2 = MaintenanceSubmission(
        id: 'test_mgam',
        templateId: 'tpl_maint_pos',
        templateName: 'Maintenance: Pos Kasir',
        userId: 'user_1',
        userName: 'Farhan Lakoro',
        userNpp: '12345',
        posId: 'pos_mgam',
        posName: 'Mie Gacoan AA Maramis',
        cabangName: 'KC BSG',
        points: [
          const MaintenancePointResult(
            pointId: 'p1',
            label: 'Pembersihan total printer pos',
            status: PointStatus.sesuai,
          ),
        ],
        createdAt: DateTime(2026, 9, 13, 10, 0),
        updatedAt: DateTime(2026, 9, 13, 10, 30),
      );
      final text2 = WhatsAppReportService.generateReportText(
        submission: sub2,
        category: TemplateCategory.maintPos,
      );
      expect(text2.contains('Lokasi : Mie Gacoan AA Maramis (MGAM)'), isTrue);
    });

    test('Server maintenance shows actual AI vision observations and zero generic "sesuai"', () {
      final submission = MaintenanceSubmission(
        id: 'test_server_ai_all',
        templateId: 'tpl_maint_server',
        templateName: 'Maintenance: Server & Kasir',
        userId: 'user_1',
        userName: 'Farhan Lakoro',
        userNpp: '12345',
        posId: 'pos_1',
        posName: 'Pos 1 Megamas',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'srv_1_01',
            label: 'Server & Kasir - Pembersihan Storage & File Temp',
            status: PointStatus.sesuai,
            alasan: 'kapasitas Drive C sisa 42GB & folder temp bersih',
          ),
          const MaintenancePointResult(
            pointId: 'srv_1_02',
            label: 'Server & Kasir - Nonaktifkan Update, Antivirus & Firewall',
            status: PointStatus.sesuai,
            alasan: 'Windows Defender dan Firewall status nonaktif (OFF)',
          ),
          const MaintenancePointResult(
            pointId: 'srv_1_03',
            label: 'Server & Kasir - Fungsi Keyboard & Mouse (Notepad Test)',
            status: PointStatus.sesuai,
            alasan: 'Notepad test 1234567890 BSS OK dan mouse aktif',
          ),
          const MaintenancePointResult(
            pointId: 'srv_1_04',
            label: 'Server & Kasir - Pembersihan Debu CPU & Pasta Processor',
            status: PointStatus.sesuai,
            alasan: 'motherboard CPU bersih dan pasta processor baru teroles',
          ),
          const MaintenancePointResult(
            pointId: 'srv_1_05',
            label: 'Server & Kasir - Port USB & Kerapian Kabel Belakang CPU',
            status: PointStatus.sesuai,
            alasan: 'port USB kencang & kabel rapi diikat spiral flexibel',
          ),
          const MaintenancePointResult(
            pointId: 'srv_1_06',
            label: 'Server & Kasir - Koneksi Jaringan Server Bebas RTO',
            status: PointStatus.sesuai,
            alasan: 'koneksi ke jaringan tidak RTO',
          ),
        ],
        createdAt: DateTime(2026, 9, 19, 10, 0),
        updatedAt: DateTime(2026, 9, 19, 10, 30),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintServer,
      );

      // Header info perangkat
      expect(text.contains('Perangkat : Server & Kasir (Gabung)'), isTrue);

      // AI Vision actual reasons
      expect(text.contains('✅ koneksi ke jaringan tidak RTO'), isTrue);
      expect(text.contains('✅ kapasitas Drive C sisa 42GB & folder temp bersih'), isTrue);
      expect(text.contains('✅ Windows Defender dan Firewall status nonaktif (OFF)'), isTrue);
      expect(text.contains('✅ Notepad test 1234567890 BSS OK dan mouse aktif'), isTrue);
      expect(text.contains('✅ motherboard CPU bersih dan pasta processor baru teroles'), isTrue);
      expect(text.contains('✅ port USB kencang & kabel rapi diikat spiral flexibel'), isTrue);

      // Zero generic "✅ sesuai"
      expect(text.contains('✅ sesuai'), isFalse);
    });

    test('Multi-unit server maintenance shows device count header and unit-specific AI reasons', () {
      final submission = MaintenanceSubmission(
        id: 'test_server_multi',
        templateId: 'tpl_maint_server',
        templateName: 'Maintenance: Server & Kasir',
        userId: 'user_1',
        userName: 'Farhan Lakoro',
        userNpp: '12345',
        posId: 'pos_1',
        posName: 'Pos 1 Megamas',
        cabangName: 'Manado',
        points: [
          const MaintenancePointResult(
            pointId: 'srv_1_06',
            label: 'Server Utama - Koneksi Jaringan Server Bebas RTO',
            status: PointStatus.sesuai,
            alasan: 'ping loss 0% koneksi ke jaringan tidak RTO',
          ),
          const MaintenancePointResult(
            pointId: 'srv_2_06',
            label: 'Kasir 1 - Koneksi Jaringan Kasir ke Server Online',
            status: PointStatus.sesuai,
            alasan: 'koneksi kasir ke database lancar online',
          ),
        ],
        createdAt: DateTime(2026, 9, 19, 10, 0),
        updatedAt: DateTime(2026, 9, 19, 10, 30),
      );

      final text = WhatsAppReportService.generateReportText(
        submission: submission,
        category: TemplateCategory.maintServer,
      );

      // Header shows 1 Server Utama & 1 Kasir
      expect(text.contains('Perangkat : 1 Server Utama & 1 Kasir'), isTrue);

      // Unit-specific AI reasons
      expect(text.contains('✅ Server Utama: ping loss 0% koneksi ke jaringan tidak RTO'), isTrue);
      expect(text.contains('✅ Kasir 1: koneksi kasir ke database lancar online'), isTrue);

      // Zero generic "✅ sesuai"
      expect(text.contains('✅ sesuai'), isFalse);
    });
  });
}

// This append is for manual check, will be removed
