import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadAppFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final fontLoader = FontLoader('PlusJakartaSans');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final file = File('assets/fonts/PlusJakartaSans-$weight.ttf');
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await fontLoader.load();

    final iconFile = File('/home/annnpii/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons');
      final iconBytes = iconFile.readAsBytesSync();
      iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await iconLoader.load();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture Concept A and Concept B for AI Validation UI', (tester) async {
    tester.view.physicalSize = const Size(820, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await loadAppFonts(tester);

    // ==========================================
    // RENDER KONSEP A: Tactical HUD Verdict (Light/Clean)
    // ==========================================
    final keyA = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'PlusJakartaSans',
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Center(
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: keyA,
                child: Container(
                  width: 380,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Point
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.print_rounded, size: 20, color: Color(0xFF1E40AF)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pos 1 - Pembersihan Total Printer Pos',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Head printer, roller karet, serbuk kertas',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const IconButton(
                              icon: Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Hero Status Card (Crimson Verdict)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'TIDAK SESUAI',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFDC2626),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: const Text(
                                    'AI Vision • 100%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Foto blur dan kurang fokus, AI tidak dapat mendeteksi kondisi fisik head printer.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Poin Temuan AI Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error_outline, size: 12, color: Color(0xFFDC2626)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Foto Kurang Fokus',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error_outline, size: 12, color: Color(0xFFDC2626)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Perlu Cek Fisik',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Panduan Sudut Foto (Kompak & Elegan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tips: Buka penutup printer, foto tegak lurus dari atas.',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Collapsible Checkpoint Accordion (Hemat Layar)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lihat 5 Checkpoint Standar SOP',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Primary CTA: Foto Ulang (Hijau Emerald)
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.camera_alt_rounded, size: 17, color: Colors.white),
                          label: const Text(
                            'Foto Ulang (Perbaiki Jadi Hijau)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Secondary Row (50:50 Grid)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.handyman_rounded, size: 15, color: Color(0xFFD97706)),
                              label: const Text(
                                'Kendala Fisik',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.edit_note_rounded, size: 17, color: Color(0xFF2563EB)),
                              label: const Text(
                                'Catatan',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundaryA = keyA.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundaryA != null) {
      await tester.runAsync(() async {
        final img = await boundaryA.toImage(pixelRatio: 2.0);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          final file = File('docs/screenshots/concept_a_tactical_hud.png');
          file.parent.createSync(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
          debugPrint('Saved Concept A: ${file.path}');
        }
      });
    }

    // ==========================================
    // RENDER KONSEP B: Minimalist Clean Inspection Sheet (Dark Studio)
    // ==========================================
    final keyB = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'PlusJakartaSans',
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: keyB,
                child: Container(
                  width: 380,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF334155), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Pill Top Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 7, color: Color(0xFFEF4444)),
                                SizedBox(width: 5),
                                Text(
                                  'TIDAK SESUAI',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF87171),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Confidence 100%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155).withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const IconButton(
                              icon: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Title
                      const Text(
                        'Pembersihan Printer Kasir',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pos 1 Keluar • PBM Manado',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 14),

                      // AI Verdict Box Minimalis
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF38BDF8)),
                                SizedBox(width: 6),
                                Text(
                                  'HASIL ANALISIS AI VISION',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF38BDF8),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Foto blur dan kurang fokus, AI tidak dapat mendeteksi kondisi head printer.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF1F5F9),
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: 10),
                            Divider(color: Color(0xFF334155), height: 1),
                            SizedBox(height: 8),
                            // Quick Action Advice
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFFFBBF24)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Buka penutup printer, bersihkan roller dari serbuk, lalu foto tegak lurus dari atas.',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1), height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Checkpoint Compact Row (Horizontal Pills)
                      const Text(
                        'CHECKPOINT CHECKLIST (5)',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          _buildDarkChip('Penutup Buka', false),
                          _buildDarkChip('Head Bersih', false),
                          _buildDarkChip('Roller Bersih', false),
                          _buildDarkChip('Bebas Serbuk', false),
                          _buildDarkChip('Kabel Kencang', false),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.camera_alt_rounded, size: 17),
                          label: const Text(
                            'Ambil Ulang Foto',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                              label: const Text(
                                'Kendala Fisik',
                                style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF78350F), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF94A3B8)),
                              label: const Text(
                                'Catatan',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF334155), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundaryB = keyB.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundaryB != null) {
      await tester.runAsync(() async {
        final img = await boundaryB.toImage(pixelRatio: 2.0);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          final file = File('docs/screenshots/concept_b_minimalist_sheet.png');
          file.parent.createSync(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
          debugPrint('Saved Concept B: ${file.path}');
        }
      });
    }
  });
}

Widget _buildDarkChip(String label, bool isOk) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFF334155)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOk ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 10,
          color: isOk ? const Color(0xFF10B981) : const Color(0xFF64748B),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
