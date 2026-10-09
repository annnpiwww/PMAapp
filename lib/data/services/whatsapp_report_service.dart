import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/share_helper.dart';
import '../models/maintenance_submission.dart';
import '../models/template_model.dart';
import '../repositories/auth_repository.dart';
import 'storage_service.dart';

class WhatsAppReportService {
  /// Format salam otomatis berdasarkan jam saat ini:
  /// - 03:00 - 10:59: Selamat Pagi
  /// - 11:00 - 14:59: Selamat Siang
  /// - 15:00 - 17:59: Selamat Sore
  /// - 18:00 - 02:59: Selamat Malam
  static String getGreeting([DateTime? time]) {
    final local = (time ?? DateTime.now()).toLocal();
    final hour = local.hour;
    if (hour >= 3 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  /// Format salam berdasarkan teks jam "HH:mm" atau "HH.mm"
  /// (misal jam masuk "10:00" -> Selamat Pagi, jam pulang "14:00" -> Selamat Siang, "18:00" -> Selamat Malam)
  static String getGreetingFromTimeString(String timeStr) {
    try {
      final clean = timeStr.trim();
      final delimiter = clean.contains(':') ? ':' : '.';
      final parts = clean.split(delimiter);
      if (parts.isNotEmpty) {
        final hour = int.parse(parts[0].trim());
        if (hour >= 3 && hour < 11) return 'Selamat Pagi';
        if (hour >= 11 && hour < 15) return 'Selamat Siang';
        if (hour >= 15 && hour < 18) return 'Selamat Sore';
        return 'Selamat Malam';
      }
    } catch (_) {}
    return getGreeting();
  }

  static const _monthsList = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static String formatIndonesianDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day} ${_monthsList[local.month]} ${local.year}';
  }

  /// Format daftar baris (multiline) menjadi auto-numbering (1. , 2. , 3. dst)
  /// Menghilangkan bullet/nomor lama acak dan menomori secara urut dan rapi,
  /// sekaligus mempertahankan baris catatan di bawah setiap poin tugas.
  static String formatAutoNumberedList(String? rawText) {
    if (rawText == null) return '-';
    final trimmed = rawText.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '-';

    final bulletRegex = RegExp(r'^(\d+[\.\)]|\-|\*|\•)\s*');
    final hasExistingBullets = lines.any((l) => bulletRegex.hasMatch(l));

    final resultLines = <String>[];
    int counter = 1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (hasExistingBullets) {
        if (bulletRegex.hasMatch(line)) {
          final clean = line.replaceFirst(bulletRegex, '').trim();
          if (clean.isNotEmpty) {
            resultLines.add('$counter. $clean');
            counter++;
          }
        } else {
          // Baris catatan/penjelasan di bawah item bernomor sebelumnya
          resultLines.add(line);
        }
      } else {
        resultLines.add('$counter. $line');
        counter++;
      }
    }

    if (resultLines.isEmpty) return '-';
    return resultLines.join('\n');
  }

  /// Membersihkan prefix label agar kalimat menjadi natural seperti contoh laporan resmi
  static String cleanItemLabel(String rawLabel) {
    var label = rawLabel;
    if (label.contains(' - ')) {
      final parts = label.split(' - ');
      if (parts.length > 1) {
        label = parts.sublist(1).join(' - ');
      }
    }

    final lower = label.toLowerCase();
    if (lower.contains('dudukan mesin')) {
      return 'Dudukan/dinabolt mesin barrier gate';
    }
    if (lower.contains('fisik palang tertutup')) {
      return 'Palang tertutup lurus normal';
    }
    if (lower.contains('fisik palang terbuka')) {
      return 'Palang terbuka tegak 90° lancar';
    }
    if (lower.contains('pelumasan mekanikal')) {
      return 'Pelumasan mekanikal spring/bearing';
    }
    if (lower.contains('sensor loop detector')) {
      return 'Sensor loop detector barrier';
    }
    if (lower.contains('jalur coran aspal')) {
      return 'Jalur coran kabel sensor loop';
    }
    if (lower.contains('pengukuran voltase')) {
      return 'Pengukuran voltase listrik avometer';
    }
    if (lower.contains('casing sensor receiver')) {
      return 'Casing sensor receiver anti air';
    }
    if (lower.contains('stiker receiver')) {
      return 'Stiker receiver barrier gate';
    }
    if (lower.contains('tiang cctv')) {
      return 'Tiang CCTV, housing dan bracket';
    }
    if (lower.contains('speed bump') || lower.contains('polisi tidur')) {
      return 'Speed bump gate';
    }

    if (lower.contains('pembersihan total printer pos')) {
      return 'Pembersihan printer pos kasir';
    }
    if (lower.contains('kerapian jalur kabel')) {
      return 'Kerapian kabel dan stopkontak pos';
    }
    if (lower.contains('standarisasi') ||
        lower.contains('meja pos') ||
        lower.contains('kelengkapan meja')) {
      return 'Standarisasi item dalam pos';
    }
    if (lower.contains('fungsi sistem') ||
        lower.contains('layar kasir') ||
        lower.contains('aplikasi kasir')) {
      return 'Fungsi sistem aplikasi kasir';
    }
    if (lower.contains('kunci pintu pos') || lower.contains('grendel pintu')) {
      return 'Kunci pintu pos (grendel pintu)';
    }
    if (lower.contains('jarak pos')) {
      return 'Jarak pos dan ujung pulau';
    }
    if (lower.contains('kondisi pulau parkir') || lower.contains('kondisi fisik pulau') || lower.contains('beton pulau')) {
      return 'Kondisi pulau parkir';
    }

    if (lower.contains('printer tiket') ||
        lower.contains('pembersihan total printer')) {
      return 'Pembersihan printer';
    }
    if (lower.contains('kebersihan dalam manless') ||
        lower.contains('dalam manless') ||
        lower.contains('interior & adaptor manless') ||
        lower.contains('kerapihan kabel dalam')) {
      return 'Kebersihan & Kerapihan kabel dalam manless';
    }
    if (lower.contains('tombol struk')) {
      return 'Fungsi tombol struk tiket keluar';
    }
    if (lower.contains('sensor loop')) {
      return 'Sensor loop kendaraan';
    }
    if (lower.contains('kebersihan luar manless') ||
        lower.contains('luar manless') ||
        lower.contains('eksterior casing') ||
        lower.contains('stiker panduan')) {
      return 'Stiker dan tampilan depan manless';
    }
    if (lower.contains('dudukan bawah manless') ||
        lower.contains('dudukan baseplate')) {
      return 'Dudukan/dinabolt bawah manless';
    }
    if (lower.contains('kunci manless') || lower.contains('gembok')) {
      return 'Kunci pintu manless';
    }

    if (lower.contains('storage file temp')) {
      return 'Pembersihan storage & file temp';
    }
    if (lower.contains('antivirus firewall')) {
      return 'Setting Windows firewall & sistem';
    }
    if (lower.contains('keyboard mouse')) {
      return 'Fungsi keyboard, mouse & scanner';
    }
    if (lower.contains('debu cpu')) {
      return 'Pembersihan debu CPU & thermal pasta';
    }
    if (lower.contains('port usb')) {
      return 'Kerapian kabel & port USB belakang CPU';
    }
    if (lower.contains('koneksi jaringan server bebas rto') ||
        lower.contains('jaringan server')) {
      return 'Koneksi jaringan server bebas RTO';
    }

    return label;
  }

  static bool _isMeaningfulAlasan(String alasan) {
    if (alasan.trim().isEmpty) return false;
    final l = alasan.toLowerCase().trim();
    if (l == 'sesuai' || l == 'ok' || l == 'sesuai.') return false;
    if (l.contains('mode offline')) return false;
    if (l.contains('offline:')) return false;
    if (l.contains('foto tersimpan')) return false;
    return true;
  }

  /// Bersihkan alasan AI agar menjadi bahasa teknisi lapangan yang natural, singkat, jelas, dan faktual
  static String cleanAlasanText(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';
    // Sanitasi: buang newline berlebih dan cegah inject laporan palsu
    text = text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

    // Normalisasi kata-kata formal / kaku ala AI ke Natural Technician Language
    text = text.replaceAll(RegExp(r'berdasarkan hasil observasi[,:\s]*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'ditemukan adanya ketidaksesuaian\s*(pada)?', caseSensitive: false), 'terdapat temuan');
    text = text.replaceAll(RegExp(r'tidak terorganisir dengan rapi', caseSensitive: false), 'tidak tertata rapi');
    text = text.replaceAll(RegExp(r'degradasi fisik', caseSensitive: false), 'kerusakan fisik');
    text = text.replaceAll(RegExp(r'mengalami deteriorasi', caseSensitive: false), 'mulai rusak');
    text = text.replaceAll(RegExp(r'parameter tidak terpenuhi', caseSensitive: false), 'tidak sesuai');
    text = text.replaceAll(RegExp(r'kondisi secara keseluruhan', caseSensitive: false), 'kondisi');
    text = text.replaceAll(RegExp(r'secara signifikan\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'dalam kondisi optimal', caseSensitive: false), 'kondisi baik dan normal');
    text = text.replaceAll(RegExp(r'memiliki integritas struktural', caseSensitive: false), 'terpasang dengan kokoh');
    text = text.replaceAll(RegExp(r'permukaan mengalami degradasi', caseSensitive: false), 'permukaan mulai rusak');
    text = text.replaceAll(RegExp(r'sesuai standar operasional', caseSensitive: false), 'berfungsi normal');
    text = text.replaceAll(RegExp(r'\bsemrawut\b', caseSensitive: false), 'kurang rapi');
    text = text.replaceAll(RegExp(r'beton pulau gate', caseSensitive: false), 'lantai pulau gate');

    // Hindari redundansi umum
    text = text.replaceAll(RegExp(r'semrawut dan tidak terorganisir.*', caseSensitive: false), 'kurang rapi dan perlu penataan kabel');
    text = text.replaceAll(RegExp(r'semrawut dan tidak tertata rapi.*', caseSensitive: false), 'kurang rapi dan perlu penataan kabel');
    text = text.replaceAll(RegExp(r'kotor,?\s*berkarat,?\s*dan mengalami degradasi fisik.*', caseSensitive: false), 'kotor dan berkarat, dengan permukaan logam mulai rusak');

    // Normalisasi jika tidak dapat diverifikasi secara visual
    if (text.toLowerCase().contains('tidak dapat diverifikasi secara visual') ||
        text.toLowerCase().contains('tidak terlihat jelas di foto')) {
      return 'perlu cek fisik langsung, tidak terlihat jelas di foto';
    }

    // Ambil 1-2 kalimat ringkas
    final sentences = text.split(RegExp(r'[.!]\s+'));
    if (sentences.length > 2) {
      text = sentences.take(2).join('. ').trim();
      if (!text.endsWith('.')) text += '.';
    } else if (text.contains('.')) {
      final first = sentences.first.trim();
      if (first.length >= 20 && first.length <= 110) {
        text = first;
      }
    }

    // Potong jika terlalu panjang (>120) agar tetap ringkas gaya teknisi
    if (text.length > 120) {
      text = '${text.substring(0, 117).trim()}...';
    }

    text = text.replaceAll(
      RegExp(
        r'^(kondisi\s+|foto hanya menampilkan\s+|foto tidak menampilkan\s+)',
        caseSensitive: false,
      ),
      '',
    );

    // Sanitasi akhir: hilangkan titik di akhir, batasi ke 1 baris
    text = text.replaceAll(RegExp(r'\.$'), '').trim();
    text = text.replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
    text = text.split('\n').first.trim();
    return text;
  }

  static bool _hasIssue(MaintenancePointResult p) {
    if (p.status == PointStatus.tidakSesuai) return true;
    if (p.status == PointStatus.perluCekManual && _isMeaningfulAlasan(p.alasan)) {
      return true;
    }
    return false;
  }

  static String _gateName(String rawLabel) {
    if (rawLabel.contains(' - ')) {
      return rawLabel.split(' - ').first.trim();
    }
    return rawLabel;
  }

  /// Helper tampilkan lokasi dengan tag: "Pasar Bersehati Manado (PBM)"
  static String _displayLokasi(MaintenanceSubmission s) {
    final base = s.posName.isNotEmpty ? s.posName : s.cabangName;
    if (base.contains('(') && base.contains(')')) return base;

    final lower = base.toLowerCase();
    if (lower.contains('pasar bersehati') && !base.contains('(PBM)')) return '$base (PBM)';
    if (lower.contains('pelabuhan kalimas') && !base.contains('(PKM)')) return '$base (PKM)';
    if ((lower.contains('mall pelayanan') || lower.contains('mall peyalanan')) && !base.contains('(MPP)')) return '$base (MPP)';
    if (lower.contains('new bendar') && !base.contains('(NBM)')) return '$base (NBM)';
    if (lower.contains('pasar pinasungkulan') && !base.contains('(PPM)')) return '$base (PPM)';
    if (lower.contains('toko bintang') && !base.contains('(TBM)')) return '$base (TBM)';
    if (lower.contains('gacoan') && lower.contains('maramis') && !base.contains('(MGAM)')) return '$base (MGAM)';
    if (lower.contains('gacoan') && lower.contains('airmadidi') && !base.contains('(MGMM)')) return '$base (MGMM)';
    if (lower.contains('gacoan') && lower.contains('babe palar') && !base.contains('(MGBP)')) return '$base (MGBP)';
    if (lower.contains('gacoan') && lower.contains('tomohon') && !base.contains('(MGTO)')) return '$base (MGTO)';
    if (lower.contains('gacoan') && lower.contains('kotamobagu') && !base.contains('(MGKB)')) return '$base (MGKB)';
    if (lower.contains('gacoan') && lower.contains('nani wartabone') && !base.contains('(MGNW)')) return '$base (MGNW)';
    if (lower.contains('gacoan') && lower.contains('jhon') && !base.contains('(MGGJ)')) return '$base (MGGJ)';
    if (lower.contains('gacoan') && lower.contains('limboto') && !base.contains('(MGLG)')) return '$base (MGLG)';

    if (base.trim().length <= 5) return base;
    // Jika submission masih tanpa tag (data lama), coba cocokkan tag dari storage tanpa paksa init SharedPreferences
    try {
      final saved = StorageService.getLocations();
      if (saved != null) {
        for (final loc in saved) {
          if (loc.posName.toLowerCase() == base.toLowerCase() &&
              loc.locationTag.trim().isNotEmpty) {
            return '$base (${loc.locationTag.trim()})';
          }
        }
      }
    } catch (_) {}
    return base;
  }

  /// Generate teks laporan resmi BSS sesuai format baku lapangan yang bersih & manusiawi
  static String generateReportText({
    required MaintenanceSubmission submission,
    required TemplateCategory category,
    int? unitCount,
    String? gateOutNotes,
    String? additionalNotes,
  }) {
    final greeting = getGreeting(submission.createdAt);
    final dateStr = formatIndonesianDate(submission.createdAt);
    final lokasi = _displayLokasi(submission);

    final supportName = () {
      final lastTech = StorageService.getLastTechnicianName().trim();
      if (lastTech.isNotEmpty && lastTech.toLowerCase() != 'teknisi bss') {
        return lastTech;
      }
      final curUser = AuthRepository.instance.currentUser?.nama.trim() ?? '';
      if (curUser.isNotEmpty && curUser.toLowerCase() != 'teknisi bss') {
        return curUser;
      }
      final savedUser = StorageService.getUser()?.nama.trim() ?? '';
      if (savedUser.isNotEmpty && savedUser.toLowerCase() != 'teknisi bss') {
        return savedUser;
      }
      if (submission.userName.isNotEmpty && submission.userName.toLowerCase() != 'teknisi bss') {
        return submission.userName;
      }
      return 'Farhan Lakoro';
    }();

    final buffer = StringBuffer();

    void appendHasilCekSummary(StringBuffer buf) {
      final sesuaiCount = submission.points.where((p) => p.status == PointStatus.sesuai).length;
      final perluCekCount = submission.points.where((p) => p.status == PointStatus.perluCekManual).length;
      final tidakSesuaiCount = submission.points.where((p) => p.status == PointStatus.tidakSesuai).length;
      final totalPoints = submission.points.length;

      buf.writeln('HASIL MAINTENANCE :');
      if (sesuaiCount > 0) {
        buf.writeln('✅ Sesuai: $sesuaiCount');
      }
      if (perluCekCount > 0) {
        buf.writeln('⚠️ Perlu Dicek: $perluCekCount');
      }
      if (tidakSesuaiCount > 0) {
        buf.writeln('⚠️ Tidak Sesuai: $tidakSesuaiCount');
      }
      buf.writeln('Total Point: $totalPoints');
      buf.writeln('');
    }

    switch (category) {
      case TemplateCategory.maintBarrier:
        buffer.writeln(greeting);
        buffer.writeln('');
        buffer.writeln(
          'Izin melaporkan hasil Maintenance Barrier Gate in, out, palang, arah sorot cctv dan sensor',
        );
        buffer.writeln('');
        buffer.writeln('Lokasi : $lokasi');
        final gateCount = unitCount ?? 1;
        String autoRangeNote = '';
        if (submission.points.isNotEmpty) {
          final set = <int>{};
          for (final p in submission.points) {
            final parts = p.pointId.split('_');
            if (parts.length >= 3) {
              final idx = int.tryParse(parts[1]);
              if (idx != null) set.add(idx);
            }
          }
          if (set.isNotEmpty) {
            final sorted = set.toList()..sort();
            if (sorted.length > 1) {
              autoRangeNote = 'Gate ${sorted.first} - Gate ${sorted.last}';
            } else {
              autoRangeNote = 'Gate ${sorted.first}';
            }
          }
        }
        if (gateCount > 1) {
          final rangePart = autoRangeNote.isNotEmpty ? ' ($autoRangeNote)' : '';
          buffer.writeln('Gate : $gateCount Unit$rangePart');
        } else {
          buffer.writeln('Gate : 1');
        }
        buffer.writeln('Tanggal : $dateStr');
        buffer.writeln('IT Support : $supportName');
        buffer.writeln('');
        appendHasilCekSummary(buffer);
        buffer.writeln('Note :');
        _appendBarrierGroupedNotes(buffer, submission.points);
        if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
          buffer.writeln('');
          buffer.writeln('Catatan tambahan: $additionalNotes');
        }
        buffer.writeln('');
        buffer.writeln('Terima kasih 🙏');
        break;

      case TemplateCategory.maintPos:
        buffer.writeln(greeting);
        buffer.writeln('');
        buffer.writeln('Izin melaporkan hasil maintenance POS');
        buffer.writeln('');
        buffer.writeln('Lokasi : $lokasi');
        final outCount = unitCount ?? 1;
        String autoRangeNote = '';
        if (submission.points.isNotEmpty) {
          final set = <int>{};
          for (final p in submission.points) {
            final parts = p.pointId.split('_');
            if (parts.length >= 3) {
              final idx = int.tryParse(parts[1]);
              if (idx != null) set.add(idx);
            }
          }
          if (set.isNotEmpty) {
            final sorted = set.toList()..sort();
            if (sorted.length > 1) {
              autoRangeNote = 'Pos ${sorted.first} - Pos ${sorted.last}';
            } else {
              autoRangeNote = 'Pos ${sorted.first}';
            }
          }
        }
        final effectiveNotes = (gateOutNotes != null && gateOutNotes.isNotEmpty)
            ? gateOutNotes
            : (autoRangeNote.isNotEmpty
                ? autoRangeNote
                : (unitCount != null && unitCount > 1 ? '1 - $outCount' : ''));
        final outNotes = effectiveNotes.isNotEmpty ? ' ($effectiveNotes)' : '';
        buffer.writeln('Gate Out : $outCount$outNotes');
        buffer.writeln('Tanggal : $dateStr');
        buffer.writeln('IT Support : $supportName');
        buffer.writeln('');
        appendHasilCekSummary(buffer);
        buffer.writeln('Note :');
        _appendPosGroupedNotes(buffer, submission.points);
        if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
          buffer.writeln('');
          buffer.writeln('Catatan tambahan: $additionalNotes');
        }
        buffer.writeln('');
        buffer.writeln('Terima kasih 🙏');
        break;

      case TemplateCategory.maintManless:
        buffer.writeln(greeting);
        buffer.writeln('');
        buffer.writeln(
          'Izin melaporkan hasil pengecekan dan pembersihan Manless',
        );
        buffer.writeln('');
        buffer.writeln('Lokasi : $lokasi');
        // Gate In info: use unitCount if provided, else derive from points
        final manlessCount =
            unitCount ??
            (submission.points.length ~/ 8 == 0
                ? 1
                : submission.points.length ~/ 8);
        if (manlessCount > 1) {
          buffer.writeln('Gate In : $manlessCount Unit');
        } else {
          // Try to extract gate identifier from first point if available
          String gateLabel = '1';
          if (submission.points.isNotEmpty) {
            final firstGate = _gateName(submission.points.first.label);
            // If gate name contains number, extract it
            final num = RegExp(r'\d+').firstMatch(firstGate);
            if (num != null) gateLabel = num.group(0)!;
          }
          buffer.writeln('Gate In : $gateLabel');
        }
        buffer.writeln('Tanggal : $dateStr');
        buffer.writeln('IT Support : $supportName');
        buffer.writeln('');
        appendHasilCekSummary(buffer);
        buffer.writeln('Note :');
        _appendManlessGroupedNotes(buffer, submission.points);
        if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
          buffer.writeln('');
          buffer.writeln('Catatan tambahan: $additionalNotes');
        }
        buffer.writeln('');
        buffer.writeln('Terima kasih 🙏');
        break;

      case TemplateCategory.maintServer:
        buffer.writeln(greeting);
        buffer.writeln('');
        final serverUnits = <String>{};
        for (final p in submission.points) {
          final u = _gateName(p.label);
          if (u.isNotEmpty) serverUnits.add(u);
        }
        final hasServer = serverUnits.any((u) => u.toLowerCase().contains('server'));
        final isAllInOne = serverUnits.any((u) => u.toLowerCase().contains('gabung') || u.toLowerCase() == 'server & kasir');
        final kasirCount = serverUnits.where((u) => u.toLowerCase().contains('kasir')).length;

        if (!hasServer) {
          buffer.writeln('Izin melaporkan hasil maintenance Komputer Kasir');
        } else {
          buffer.writeln(
            'Izin melaporkan hasil maintenance Server & Komputer Kasir',
          );
        }
        buffer.writeln('');
        buffer.writeln('Lokasi : $lokasi');
        if (isAllInOne) {
          buffer.writeln('Perangkat : Server & Kasir (Gabung)');
        } else if (hasServer) {
          if (kasirCount > 0) {
            buffer.writeln('Perangkat : 1 Server Utama & $kasirCount Kasir');
          } else {
            buffer.writeln('Perangkat : 1 Server Utama');
          }
        } else {
          buffer.writeln('Perangkat : $kasirCount PC Kasir');
        }
        buffer.writeln('Tanggal : $dateStr');
        buffer.writeln('IT Support : $supportName');
        buffer.writeln('');
        appendHasilCekSummary(buffer);
        buffer.writeln('Note :');
        _appendServerGroupedNotes(buffer, submission.points);
        if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
          buffer.writeln('');
          buffer.writeln('Catatan tambahan: $additionalNotes');
        }
        buffer.writeln('');
        buffer.writeln('Terima kasih 🙏');
        break;

      default:
        buffer.writeln(greeting);
        buffer.writeln(
          'Izin melaporkan hasil pemeriksaan ${submission.templateName} Lokasi $lokasi',
        );
        buffer.writeln('Tanggal : $dateStr');
        buffer.writeln('IT Support : $supportName');
        buffer.writeln('');
        appendHasilCekSummary(buffer);
        buffer.writeln('Note :');
        _appendCleanNotes(
          buffer,
          submission.points,
          defaultNotes: ['semua item diperiksa berfungsi normal'],
        );
        if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
          buffer.writeln('');
          buffer.writeln('Catatan tambahan: $additionalNotes');
        }
        buffer.writeln('');
        buffer.writeln('Terima kasih 🙏');
    }

    return buffer.toString().trim();
  }

  /// Kondisi observasi positif faktual default jika alasan AI kosong/offline (anti kata "sesuai" generic)
  static String _defaultObservationForTheme(String themeLabel) {
    final l = themeLabel.toLowerCase();
    // Server & Kasir
    if (l.contains('storage') || l.contains('file temp')) {
      return 'kapasitas storage/partisi aman & folder temp/log bersih';
    }
    if (l.contains('antivirus') || l.contains('firewall') || l.contains('update')) {
      return 'firewall & auto-update dalam status nonaktif (OFF)';
    }
    if (l.contains('keyboard') || l.contains('mouse') || l.contains('notepad') || l.contains('console') || l.contains('input test')) {
      return 'input keyboard & navigasi merespons lancar (pengujian teks OK)';
    }
    if (l.contains('debu cpu') || l.contains('pasta') || l.contains('thermal')) {
      return 'motherboard CPU bersih & pasta processor baru teroles';
    }
    if (l.contains('port usb') || l.contains('kabel belakang')) {
      return 'kabel rapi terikat & port USB terhubung kencang';
    }
    if (l.contains('koneksi jaringan') || l.contains('bebas rto') || l.contains('server online')) {
      return 'koneksi ke jaringan stabil tidak RTO';
    }

    // Barrier Gate
    if (l.contains('dudukan mesin') || l.contains('dynabolt') || l.contains('dinabolt')) {
      return 'dudukan mesin kokoh & baut dynabolt kencang';
    }
    if (l.contains('palang tertutup')) {
      return 'palang posisi tertutup 0° lurus & baut pengikat kencang';
    }
    if (l.contains('palang terbuka')) {
      return 'palang terbuka tegak 90° bergerak lancar';
    }
    if (l.contains('pelumas') || l.contains('bearing') || l.contains('spring')) {
      return 'per spring & bearing terlumasi grease baru';
    }
    if (l.contains('sensor loop') || l.contains('led detect')) {
      return 'sensor loop aktif mendeteksi kendaraan (LED Detect aktif)';
    }
    if (l.contains('jalur kabel') || l.contains('coran aspal')) {
      return 'jalur kabel sensor tertutup coran rata rapi';
    }
    if (l.contains('stiker receiver') || l.contains('stiker barrier') || (l.contains('stiker') && !l.contains('bss') && !l.contains('parkways') && !l.contains('manless'))) {
      return 'stiker receiver kuning utuh rapi bebas retak/buram';
    }
    if (l.contains('tiang cctv') || l.contains('housing')) {
      return 'tiang CCTV kokoh & housing kamera bersih bening';
    }
    if (l.contains('speedbump') || l.contains('speed bump')) {
      return 'karet speed bump kokoh terpasang kuat dengan dynabolt';
    }

    // Pos Kasir
    if (l.contains('printer pos') || l.contains('total printer pos')) {
      return 'printer bersih, head & roller bebas debu kertas';
    }
    if (l.contains('jalur kabel') || l.contains('stopkontak')) {
      return 'jalur kabel rapi terikat & stopkontak aman';
    }
    if (l.contains('standarisasi item') || l.contains('meja pos') || l.contains('kelengkapan meja')) {
      return 'meja pos bersih & kelengkapan tertata rapi';
    }
    if (l.contains('aplikasi kasir') || l.contains('fungsi sistem') || l.contains('layar kasir')) {
      return 'aplikasi kasir online siap melayani';
    }
    if (l.contains('kunci pintu') || l.contains('grendel')) {
      return 'kunci pintu & grendel pos berfungsi normal';
    }
    if (l.contains('stiker bss') || l.contains('parkways') || l.contains('stiker')) {
      return 'stiker BSS Parking & Parkways rapi utuh';
    }
    if (l.contains('pulau parkir') || l.contains('kondisi pulau')) {
      return 'kondisi fisik pulau parkir rapi & cat bersih';
    }

    // Manless
    if (l.contains('printer tiket')) {
      return 'area roller dan head thermal bersih serta bebas debu';
    }
    if (l.contains('dalam manless')) {
      return 'ruang dalam manless bersih dan kabel tertata rapi';
    }
    if (l.contains('tombol') || l.contains('struk') || l.contains('tiket keluar')) {
      return 'tombol tiket berfungsi normal dan struk tercetak dengan baik';
    }
    if (l.contains('layar/led') || l.contains('layar lcd') || l.contains('sensor loop kendaraan')) {
      return 'sensor loop aktif dan layar dispenser berfungsi normal';
    }
    if (l.contains('luar manless')) {
      return 'body manless bersih dan stiker panduan masih utuh';
    }
    if (l.contains('dudukan bawah')) {
      return 'dudukan bawah manless kokoh dan baut dynabolt kencang';
    }
    if (l.contains('lantai dan beton') || l.contains('beton pulau gate') || l.contains('fisik beton')) {
      return 'beton pulau gate bersih dan permukaan lantai rapi';
    }
    if (l.contains('kunci manless') || l.contains('gembok')) {
      return 'kunci manless bersih, tidak berkarat, dan terpasang kokoh';
    }

    return 'kondisi bersih prima, terpasang kokoh, dan berfungsi normal';
  }

  /// Format alasan hijau (sesuai):
  /// Mengembalikan hasil validasi AI Vision jika bermakna dan bukan kata generic "sesuai"/"ok".
  static String _formatOkAlasan(String rawAlasan, {String fallback = ''}) {
    if (_isMeaningfulAlasan(rawAlasan)) {
      final cleaned = cleanAlasanText(rawAlasan);
      if (cleaned.isNotEmpty &&
          cleaned.toLowerCase() != 'sesuai' &&
          cleaned.toLowerCase() != 'ok') {
        return cleaned;
      }
    }
    return fallback;
  }

  /// Cari alasan AI vision terbaik dari sekumpulan point sesuai
  static String _findBestOkAlasan(
    List<MaintenancePointResult> points, {
    String fallback = '',
  }) {
    for (final p in points) {
      final formatted = _formatOkAlasan(p.alasan, fallback: '');
      if (formatted.isNotEmpty) {
        return formatted;
      }
    }
    return fallback;
  }

  /// Model 1 Formatter: Memisahkan unit yang sesuai (hijau) dan unit yang bermasalah (warning).
  /// Menampilkan hasil observasi AI aktual pada status hijau, anti-kata "sesuai" generic.
  static void _appendThematicModel1Line({
    required StringBuffer buffer,
    required int no,
    required String themeLabel,
    required List<MaintenancePointResult> relevant,
  }) {
    final done = relevant
        .where((p) => p.status != PointStatus.belumFoto)
        .toList();
    if (done.isEmpty) {
      buffer.writeln('$no. *${themeLabel.trim()}* :');
      buffer.writeln('   ⚠️ belum diperiksa');
      return;
    }

    final issues = done
        .where((p) => p.status == PointStatus.tidakSesuai || _hasIssue(p))
        .toList();
    final okPoints = done
        .where((p) => p.status == PointStatus.sesuai && !_hasIssue(p))
        .toList();

    buffer.writeln('$no. *${themeLabel.trim()}* :');

    final uniqueUnits = relevant.map((p) => _gateName(p.label)).toSet();
    final isSingleUnit = relevant.length <= 1 || uniqueUnits.length <= 1;
    final defaultOk = _defaultObservationForTheme(themeLabel);

    // 1. Jika SEMUA unit sesuai (tidak ada issue)
    if (issues.isEmpty) {
      if (done.length < relevant.length) {
        buffer.writeln('   ⚠️ baru ${done.length}/${relevant.length} unit diperiksa (semua aman)');
      } else if (isSingleUnit) {
        final okAlasan = _findBestOkAlasan(okPoints, fallback: defaultOk);
        buffer.writeln('   ✅ $okAlasan');
      } else {
        final unitReasons = <String, String>{};
        for (final p in okPoints) {
          final u = _gateName(p.label);
          final r = _formatOkAlasan(p.alasan, fallback: defaultOk);
          unitReasons[u] = r;
        }

        final distinct = unitReasons.values.toSet();
        if (distinct.length == 1) {
          buffer.writeln('   ✅ ${distinct.first}');
        } else {
          for (final entry in unitReasons.entries) {
            buffer.writeln('   ✅ ${entry.key}: ${entry.value}');
          }
        }
      }
      return;
    }

    // 2. Jika SEMUA unit bermasalah (tidak ada yang hijau)
    if (okPoints.isEmpty) {
      for (final iss in issues) {
        final alasan = _isMeaningfulAlasan(iss.alasan)
            ? cleanAlasanText(iss.alasan)
            : 'perlu perbaikan';
        if (isSingleUnit) {
          buffer.writeln('   ⚠️ $alasan');
        } else {
          final unit = _gateName(iss.label);
          buffer.writeln('   ⚠️ $unit: $alasan');
        }
        if (iss.kendalaFisik != null && iss.kendalaFisik!.trim().isNotEmpty) {
          buffer.writeln('      👉 KENDALA: ${iss.kendalaFisik!.trim()}');
        }
      }
      return;
    }

    // 3. MODEL 1: CAMPUR (Ada yang hijau, ada yang bermasalah)
    if (isSingleUnit) {
      final okAlasan = _findBestOkAlasan(okPoints, fallback: defaultOk);
      buffer.writeln('   ✅ $okAlasan');
      for (final iss in issues) {
        final alasan = _isMeaningfulAlasan(iss.alasan)
            ? cleanAlasanText(iss.alasan)
            : 'perlu perbaikan';
        buffer.writeln('   ⚠️ $alasan');
        if (iss.kendalaFisik != null && iss.kendalaFisik!.trim().isNotEmpty) {
          buffer.writeln('      👉 KENDALA: ${iss.kendalaFisik!.trim()}');
        }
      }
    } else {
      final unitReasons = <String, String>{};
      for (final p in okPoints) {
        final u = _gateName(p.label);
        final r = _formatOkAlasan(p.alasan, fallback: defaultOk);
        unitReasons[u] = r;
      }

      final distinct = unitReasons.values.toSet();
      if (unitReasons.length == 1) {
        buffer.writeln('   ✅ ${unitReasons.keys.first}: ${unitReasons.values.first}');
      } else if (distinct.length == 1) {
        buffer.writeln('   ✅ ${unitReasons.keys.join(', ')}: ${distinct.first}');
      } else {
        for (final entry in unitReasons.entries) {
          buffer.writeln('   ✅ ${entry.key}: ${entry.value}');
        }
      }

      for (final iss in issues) {
        final unit = _gateName(iss.label);
        final alasan = _isMeaningfulAlasan(iss.alasan)
            ? cleanAlasanText(iss.alasan)
            : 'perlu perbaikan';
        buffer.writeln('   ⚠️ $unit: $alasan');
        if (iss.kendalaFisik != null && iss.kendalaFisik!.trim().isNotEmpty) {
          buffer.writeln('      👉 KENDALA: ${iss.kendalaFisik!.trim()}');
        }
      }
    }
  }

  /// Laporan Barrier Gate (Model 1 Grouping - 9 Poin Baku 1:1)
  static void _appendBarrierGroupedNotes(
    StringBuffer buffer,
    List<MaintenancePointResult> points,
  ) {
    if (points.isEmpty) {
      const defaults = [
        'dudukan mesin & Baut dynabolt',
        'fisik palang tertutup lurus',
        'fisik palang terbuka',
        'pelumas (spring/bearing)',
        'sensor loop detector',
        'jalur kabel sensor',
        'stiker receiver barrier gate',
        'tiang cctv & Housing',
        'speedbump gate',
      ];
      for (int i = 0; i < defaults.length; i++) {
        buffer.writeln('${i + 1}. *${defaults[i].trim()}* :');
        buffer.writeln('   ✅ ${_defaultObservationForTheme(defaults[i])}');
      }
      return;
    }

    List<MaintenancePointResult> filterByKeywords(List<String> keywords) {
      return points.where((p) {
        final l = p.label.toLowerCase();
        return keywords.any((k) => l.contains(k));
      }).toList();
    }

    _appendThematicModel1Line(
      buffer: buffer,
      no: 1,
      themeLabel: 'dudukan mesin & Baut dynabolt',
      relevant: filterByKeywords(['dudukan mesin', 'dynabolt', 'dinabolt']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 2,
      themeLabel: 'fisik palang tertutup lurus',
      relevant: filterByKeywords(['palang tertutup']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 3,
      themeLabel: 'fisik palang terbuka',
      relevant: filterByKeywords(['palang terbuka']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 4,
      themeLabel: 'pelumas (spring/bearing)',
      relevant: filterByKeywords(['pelumas', 'pelumasan', 'spring/bearing', 'bearing']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 5,
      themeLabel: 'sensor loop detector',
      relevant: filterByKeywords(['sensor loop', 'loop detector', 'led detect', 'modul loop']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 6,
      themeLabel: 'jalur kabel sensor',
      relevant: filterByKeywords(['jalur kabel sensor', 'kabel sensor', 'coran aspal', 'garis coran']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 7,
      themeLabel: 'stiker receiver barrier gate',
      relevant: filterByKeywords(['stiker receiver', 'stiker barrier', 'receiver', 'stiker']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 8,
      themeLabel: 'tiang cctv & Housing',
      relevant: filterByKeywords(['tiang cctv', 'housing']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 9,
      themeLabel: 'speedbump gate',
      relevant: filterByKeywords(['speedbump', 'speed bump']),
    );
  }

  /// Laporan Pos Parkir (Model 1 Grouping)
  static void _appendPosGroupedNotes(
    StringBuffer buffer,
    List<MaintenancePointResult> points,
  ) {
    if (points.isEmpty) {
      const defaults = [
        'Pembersihan total printer pos',
        'Kerapian jalur kabel & stopkontak',
        'Standarisasi item dalam pos',
        'Fungsi sistem aplikasi kasir',
        'Kunci pintu pos (grendel pintu)',
        'Stiker BSS Parking & Parkways',
        'Kondisi pulau parkir',
      ];
      for (int i = 0; i < defaults.length; i++) {
        buffer.writeln('${i + 1}. *${defaults[i].trim()}* :');
        buffer.writeln('   ✅ ${_defaultObservationForTheme(defaults[i])}');
      }
      return;
    }

    List<MaintenancePointResult> filterByKeywords(List<String> keywords) {
      return points.where((p) {
        final l = p.label.toLowerCase();
        return keywords.any((k) => l.contains(k));
      }).toList();
    }

    _appendThematicModel1Line(
      buffer: buffer,
      no: 1,
      themeLabel: 'Pembersihan total printer pos',
      relevant: filterByKeywords(['pembersihan total printer', 'printer pos']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 2,
      themeLabel: 'Kerapian jalur kabel & stopkontak',
      relevant: filterByKeywords(['kerapian jalur kabel', 'jalur kabel', 'stopkontak']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 3,
      themeLabel: 'Standarisasi item dalam pos',
      relevant: filterByKeywords(['standarisasi item', 'standarisasi meja', 'kelengkapan meja', 'meja pos', 'kipas angin']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 4,
      themeLabel: 'Fungsi sistem aplikasi kasir',
      relevant: filterByKeywords(['fungsi sistem', 'layar kasir', 'aplikasi kasir']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 5,
      themeLabel: 'Kunci pintu pos (grendel pintu)',
      relevant: filterByKeywords(['kunci pintu', 'grendel pintu']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 6,
      themeLabel: 'Stiker BSS Parking & Parkways',
      relevant: filterByKeywords(['stiker']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 7,
      themeLabel: 'Kondisi pulau parkir',
      relevant: filterByKeywords(['kondisi pulau', 'pulau parkir', 'ujung pulau']),
    );
  }

  /// Laporan Manless (Model 1 Grouping)
  static void _appendManlessGroupedNotes(
    StringBuffer buffer,
    List<MaintenancePointResult> points,
  ) {
    if (points.isEmpty) {
      const defaults = [
        'Pembersihan total printer tiket',
        'Kebersihan dalam manless & kerapihan kabel',
        'Fungsi tombol struk & tiket keluar',
        'Sensor loop kendaraan (layar/LED aktif)',
        'Kebersihan luar manless & stiker panduan',
        'Dudukan bawah manless ke pulau',
        'Kondisi fisik lantai dan beton pulau gate',
        'Kunci manless & gembok',
      ];
      for (int i = 0; i < defaults.length; i++) {
        buffer.writeln('${i + 1}. *${defaults[i].trim()}* :');
        buffer.writeln('   ✅ ${_defaultObservationForTheme(defaults[i])}');
      }
      return;
    }

    List<MaintenancePointResult> filterByKeywords(List<String> keywords) {
      return points.where((p) {
        final l = p.label.toLowerCase();
        return keywords.any((k) => l.contains(k));
      }).toList();
    }

    _appendThematicModel1Line(
      buffer: buffer,
      no: 1,
      themeLabel: 'Pembersihan total printer tiket',
      relevant: filterByKeywords(['printer tiket', 'pembersihan printer', 'pembersihan total printer']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 2,
      themeLabel: 'Kebersihan dalam manless & kerapihan kabel',
      relevant: filterByKeywords(['kabel dalam manless', 'kebersihan dalam manless', 'kebersihan & kerapihan kabel']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 3,
      themeLabel: 'Fungsi tombol struk & tiket keluar',
      relevant: filterByKeywords(['tombol struk', 'tiket keluar', 'tombol tiket']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 4,
      themeLabel: 'Sensor loop kendaraan (layar/LED aktif)',
      relevant: filterByKeywords(['sensor loop', 'layar/led', 'layar lcd']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 5,
      themeLabel: 'Kebersihan luar manless & stiker panduan',
      relevant: filterByKeywords(['luar manless', 'stiker panduan', 'stiker dan tampilan']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 6,
      themeLabel: 'Dudukan bawah manless ke pulau',
      relevant: filterByKeywords(['dudukan bawah', 'dudukan/dinabolt']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 7,
      themeLabel: 'Kondisi fisik lantai dan beton pulau gate',
      relevant: filterByKeywords(['beton pulau', 'lantai dan beton']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 8,
      themeLabel: 'Kunci manless & gembok',
      relevant: filterByKeywords(['kunci manless', 'kunci pintu manless', 'gembok']),
    );
  }

  /// Laporan Server & Kasir (Model 1 Grouping)
  static void _appendServerGroupedNotes(
    StringBuffer buffer,
    List<MaintenancePointResult> points,
  ) {
    if (points.isEmpty) {
      const defaults = [
        'Pembersihan storage & file temp',
        'Nonaktifkan update, antivirus & firewall',
        'Fungsi keyboard & mouse (input test)',
        'Pembersihan debu CPU & pasta processor',
        'Port USB & kerapian kabel belakang CPU',
        'Koneksi jaringan server bebas RTO & kasir online',
      ];
      for (int i = 0; i < defaults.length; i++) {
        buffer.writeln('${i + 1}. *${defaults[i].trim()}* :');
        buffer.writeln('   ✅ ${_defaultObservationForTheme(defaults[i])}');
      }
      return;
    }

    List<MaintenancePointResult> filterByKeywords(List<String> keywords) {
      return points.where((p) {
        final l = p.label.toLowerCase();
        return keywords.any((k) => l.contains(k));
      }).toList();
    }

    _appendThematicModel1Line(
      buffer: buffer,
      no: 1,
      themeLabel: 'Pembersihan storage & file temp',
      relevant: filterByKeywords(['storage', 'file temp']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 2,
      themeLabel: 'Nonaktifkan update, antivirus & firewall',
      relevant: filterByKeywords(['antivirus', 'firewall', 'update']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 3,
      themeLabel: 'Fungsi keyboard & mouse (input test)',
      relevant: filterByKeywords(['keyboard', 'mouse', 'notepad', 'console']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 4,
      themeLabel: 'Pembersihan debu CPU & pasta processor',
      relevant: filterByKeywords(['debu cpu', 'pasta processor', 'thermal pasta', 'motherboard cpu']),
    );
    _appendThematicModel1Line(
      buffer: buffer,
      no: 5,
      themeLabel: 'Port USB & kerapian kabel belakang CPU',
      relevant: filterByKeywords(['port usb', 'kerapian kabel', 'kabel belakang']),
    );
    final hasServer = points.any((p) => p.label.toLowerCase().contains('server'));
    _appendThematicModel1Line(
      buffer: buffer,
      no: 6,
      themeLabel: hasServer
          ? 'Koneksi jaringan server bebas RTO & kasir online'
          : 'Koneksi jaringan bebas RTO & kasir online',
      relevant: filterByKeywords([
        'koneksi jaringan',
        'server bebas rto',
        'server online',
        'bebas rto',
        'jaringan kasir',
        'kasir ke server online',
      ]),
    );
  }

  static void _appendCleanNotes(
    StringBuffer buffer,
    List<MaintenancePointResult> points, {
    required List<String> defaultNotes,
  }) {
    if (points.isEmpty) {
      int n = 1;
      for (final note in defaultNotes) {
        buffer.writeln('$n. *${note.trim()}* :');
        buffer.writeln('   ✅ ${_defaultObservationForTheme(note)}');
        n++;
      }
      return;
    }

    int idx = 1;
    for (final p in points) {
      final cleanLabel = cleanItemLabel(p.label);
      buffer.writeln('$idx. *${cleanLabel.trim()}* :');
      if (p.status == PointStatus.belumFoto) {
        buffer.writeln('   ⚠️ belum diperiksa');
      } else if (p.status == PointStatus.sesuai) {
        final okAlasan = _isMeaningfulAlasan(p.alasan)
            ? cleanAlasanText(p.alasan)
            : '';
        if (okAlasan.isNotEmpty && okAlasan.toLowerCase() != 'sesuai') {
          buffer.writeln('   ✅ $okAlasan');
        } else {
          buffer.writeln('   ✅ ${_defaultObservationForTheme(cleanLabel)}');
        }
      } else {
        // tidakSesuai / perluCekManual -> warning
        final rawAlasan = _isMeaningfulAlasan(p.alasan)
            ? cleanAlasanText(p.alasan)
            : '';
        if (rawAlasan.isNotEmpty) {
          buffer.writeln('   ⚠️ $rawAlasan');
        } else {
          buffer.writeln('   ⚠️ perlu perbaikan');
        }
      }
      idx++;
    }
  }

  /// Bagikan laporan teks dan file-file foto sekaligus ke WhatsApp
  static Future<void> shareToWhatsApp({
    required MaintenanceSubmission submission,
    required TemplateCategory category,
    int? unitCount,
    String? gateOutNotes,
    String? additionalNotes,
  }) async {
    final text = generateReportText(
      submission: submission,
      category: category,
      unitCount: unitCount,
      gateOutNotes: gateOutNotes,
      additionalNotes: additionalNotes,
    );

    final xfiles = <XFile>[];
    for (final pt in submission.points) {
      if (pt.imagePath != null && pt.imagePath!.isNotEmpty) {
        if (kIsWeb) {
          xfiles.add(XFile(pt.imagePath!, name: '${pt.pointId}.jpg'));
        } else {
          final f = File(pt.imagePath!);
          if (f.existsSync()) {
            xfiles.add(XFile(pt.imagePath!, name: '${pt.pointId}.jpg'));
          }
        }
      }
    }

    final filePaths = xfiles.map((e) => e.path).toList();
    await ShareHelper.shareToWhatsApp(
      text: text,
      imagePaths: filePaths.isNotEmpty ? filePaths : null,
    );
  }

  /// Bagikan laporan teks dan file-file foto ke Telegram (Direct Intent tanpa dialog chooser)
  static Future<void> shareToTelegram({
    required MaintenanceSubmission submission,
    required TemplateCategory category,
    int? unitCount,
    String? gateOutNotes,
    String? additionalNotes,
  }) async {
    final text = generateReportText(
      submission: submission,
      category: category,
      unitCount: unitCount,
      gateOutNotes: gateOutNotes,
      additionalNotes: additionalNotes,
    );

    final xfiles = <XFile>[];
    for (final pt in submission.points) {
      if (pt.imagePath != null && pt.imagePath!.isNotEmpty) {
        if (kIsWeb) {
          xfiles.add(XFile(pt.imagePath!, name: '${pt.pointId}.jpg'));
        } else {
          final f = File(pt.imagePath!);
          if (f.existsSync()) {
            xfiles.add(XFile(pt.imagePath!, name: '${pt.pointId}.jpg'));
          }
        }
      }
    }

    final filePaths = xfiles.map((e) => e.path).toList();
    await ShareHelper.shareToTelegram(
      text: text,
      imagePaths: filePaths.isNotEmpty ? filePaths : null,
    );
  }
}
