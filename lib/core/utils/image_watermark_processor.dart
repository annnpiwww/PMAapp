import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'timemark_formatter.dart';
import '../../data/models/watermark_config.dart';
import '../../data/services/branch_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/storage_service.dart';

class ImageWatermarkProcessor {
  /// Generates an ultra-optimized lightweight base64 JPEG thumbnail for AI Vision verification.
  /// Uses 512px width with quality 60 (~15-25KB payload) for near-instant upload & inference
  /// (<1s transfer latency on cellular 4G/H+) while keeping sufficient visual clarity
  /// for uniform, ID Card, pin smile, and maintenance hardware elements.
  static Future<String?> generateAiVisionBase64(
    String imagePath, [
    Uint8List? directBytes,
    bool isFrontCamera = false,
    double? targetAspectRatio,
  ]) async {
    try {
      Uint8List? bytes = directBytes;
      if (bytes == null) {
        if (!kIsWeb) {
          final file = File(imagePath);
          if (file.existsSync()) {
            bytes = await file.readAsBytes();
          }
        }
      }
      if (bytes == null || bytes.isEmpty) return null;
      final validBytes = bytes;

      // Khusus Platform WEB: Gunakan pure-Dart decoding & resizing via `package:image`
      // agar 100% kompatibel di browser/PWA tanpa ketergantungan dart:ui Image.toByteData / isolate.
      if (kIsWeb) {
        try {
          final decoded = imglib.decodeImage(validBytes);
          if (decoded != null) {
            imglib.Image processed = decoded;
            if (targetAspectRatio != null) {
              final srcAspect = decoded.width / decoded.height;
              if ((srcAspect - targetAspectRatio).abs() > 0.02) {
                int cropW = decoded.width;
                int cropH = decoded.height;
                int cropX = 0;
                int cropY = 0;
                if (srcAspect > targetAspectRatio) {
                  cropW = (decoded.height * targetAspectRatio).round();
                  cropX = (decoded.width - cropW) ~/ 2;
                } else {
                  cropH = (decoded.width / targetAspectRatio).round();
                  cropY = (decoded.height - cropH) ~/ 2;
                }
                processed = imglib.copyCrop(
                  decoded,
                  x: cropX,
                  y: cropY,
                  width: cropW,
                  height: cropH,
                );
              }
            }
            if (isFrontCamera) {
              processed = imglib.flipHorizontal(processed);
            }
            // Resize ke lebar 480px untuk payload AI ultra-ringan (~25KB)
            final resized = imglib.copyResize(processed, width: 480);
            final jpegBytes = imglib.encodeJpg(resized, quality: 60);
            return base64Encode(jpegBytes);
          }
        } catch (e) {
          debugPrint('[ImageWatermarkProcessor] Web pure-Dart resize error: $e');
        }
        // Fallback jika decode gagal: encode directBytes langsung
        return base64Encode(validBytes);
      }

      // Platform NATIVE (Android / iOS):
      // 420px width @ Q50 drops payload to ~25-35KB for lightning-fast network transmission on mobile 4G/3G
      final codec = await ui.instantiateImageCodec(validBytes, targetWidth: 420);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final srcAspect = img.width / img.height;
      double cropX = 0;
      double cropY = 0;
      double cropW = img.width.toDouble();
      double cropH = img.height.toDouble();

      if (targetAspectRatio != null && (srcAspect - targetAspectRatio).abs() > 0.01) {
        if (srcAspect > targetAspectRatio) {
          cropW = img.height * targetAspectRatio;
          cropX = (img.width - cropW) / 2.0;
        } else {
          cropH = img.width / targetAspectRatio;
          cropY = (img.height - cropH) / 2.0;
        }
      }

      final canvasW = cropW;
      final canvasH = cropH;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, canvasW, canvasH),
      );

      final srcRect = Rect.fromLTWH(cropX, cropY, cropW, cropH);
      final dstRect = Rect.fromLTWH(0, 0, canvasW, canvasH);
      if (isFrontCamera) {
        canvas.translate(canvasW, 0);
        canvas.scale(-1.0, 1.0);
        canvas.drawImageRect(img, srcRect, dstRect, Paint());
      } else {
        canvas.drawImageRect(img, srcRect, dstRect, Paint());
      }
      final picture = recorder.endRecording();
      final finalImg = await picture.toImage(canvasW.toInt(), canvasH.toInt());

      final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null) {
        final rgbaBytes = byteData.buffer.asUint8List();
        // Offload encoding ke background isolate agar UI thread 60fps mulus tanpa stutter
        final jpegBytes = await compute(
          _encodeRgbaToJpegIsolate,
          _RgbaEncodePayload(finalImg.width, finalImg.height, rgbaBytes, 50),
        );
        if (jpegBytes.isNotEmpty) {
          return base64Encode(jpegBytes);
        }
      }
      return base64Encode(validBytes);
    } catch (_) {
      if (directBytes != null && directBytes.isNotEmpty) {
        return base64Encode(directBytes);
      }
    }
    return null;
  }

  /// Burns the live camera watermark directly onto the captured photo file with optimized performance.
  /// Supports [targetAspectRatio] (e.g. Full ratio, 3:4, 1:1, 9:16) with center-crop to match viewfinder.
  static Future<String> applyWatermarkToFile({
    required String imagePath,
    required DateTime timestamp,
    required double? lat,
    required double? lng,
    required String fullAddress,
    required String kodeVerifikasi,
    required WatermarkConfig config,
    required String activeLocationTag,
    required Color activeLocationColor,
    String? pointLabel,
    bool isAbsensi = false,
    bool isFrontCamera = false,
    double? targetAspectRatio,
    int jpegQuality = 93,
  }) async {
    if (kIsWeb) return imagePath;
    final file = File(imagePath);
    if (!file.existsSync()) return imagePath;

    final sw = Stopwatch()..start();
    try {
      final bytes = await file.readAsBytes();

      // Optimize: Cap max dimension to 1920 (Full HD) to prevent Out-Of-Memory on mobile cameras (12MP-48MP)
      // and ensure ultra-fast watermark rendering in <400ms while preserving crystal-clear sharpness.
      int? targetW;
      int? targetH;
      try {
        final descriptor = await ui.ImageDescriptor.encoded(
          await ui.ImmutableBuffer.fromUint8List(bytes),
        );
        final origW = descriptor.width;
        final origH = descriptor.height;
        descriptor.dispose();
        const maxDim = 1920;
        if (origW > maxDim || origH > maxDim) {
          if (origW >= origH) {
            targetW = maxDim;
          } else {
            targetH = maxDim;
          }
        }
      } catch (_) {}

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      final srcAspect = originalImage.width / originalImage.height;
      double cropX = 0;
      double cropY = 0;
      double cropW = originalImage.width.toDouble();
      double cropH = originalImage.height.toDouble();

      // Support Aspect Ratio (Full ratio, 3:4, 1:1, 9:16) with center-crop to match viewfinder precisely
      if (targetAspectRatio != null && (srcAspect - targetAspectRatio).abs() > 0.01) {
        if (srcAspect > targetAspectRatio) {
          // Source wider than target -> crop left/right sides
          cropW = originalImage.height * targetAspectRatio;
          cropX = (originalImage.width - cropW) / 2.0;
        } else {
          // Source taller than target -> crop top/bottom
          cropH = originalImage.width / targetAspectRatio;
          cropY = (originalImage.height - cropH) / 2.0;
        }
      }

      final canvasW = cropW;
      final canvasH = cropH;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

      // 1. Draw original photo (flip horizontal if front camera so photo matches UI viewfinder preview)
      final srcRect = Rect.fromLTWH(cropX, cropY, cropW, cropH);
      final dstRect = Rect.fromLTWH(0, 0, canvasW, canvasH);
      if (isFrontCamera) {
        canvas.save();
        canvas.translate(canvasW, 0);
        canvas.scale(-1.0, 1.0);
        canvas.drawImageRect(
          originalImage,
          srcRect,
          dstRect,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      } else {
        canvas.drawImageRect(
          originalImage,
          srcRect,
          dstRect,
          Paint()..filterQuality = FilterQuality.high,
        );
      }
      final imgWidth = canvasW;
      final imgHeight = canvasH;

      final baseScale = (imgWidth / 420.0).clamp(0.8, 12.0);
      final scale = baseScale * config.scale;

      String badgeTag;
      final Color badgeColor;
      if (isAbsensi) {
        badgeTag = config.badgeTag.isNotEmpty
            ? config.badgeTag
            : (activeLocationTag.isNotEmpty ? activeLocationTag : 'Absensi');
        badgeColor = config.badgeColor != const Color(0xFFF59E0B)
            ? config.badgeColor
            : activeLocationColor;
      } else if (pointLabel != null || (activeLocationTag.isNotEmpty && activeLocationTag.toLowerCase() != 'absensi')) {
        // Mode maintenance / non-absensi: utamakan tag lokasi maintenance (misal 'PBM', 'TBM', 'MEGAMAS')
        if (activeLocationTag.isNotEmpty && activeLocationTag.toLowerCase() != 'absensi') {
          badgeTag = activeLocationTag;
          badgeColor = activeLocationColor;
        } else if (config.badgeTag.isNotEmpty && config.badgeTag.toLowerCase() != 'absensi') {
          badgeTag = config.badgeTag;
          badgeColor = config.badgeColor != const Color(0xFFF59E0B) ? config.badgeColor : activeLocationColor;
        } else {
          badgeTag = activeLocationTag.isNotEmpty ? activeLocationTag : 'BSS';
          badgeColor = activeLocationColor;
        }
      } else {
        badgeTag = config.badgeTag.isNotEmpty ? config.badgeTag : activeLocationTag;
        badgeColor = config.badgeColor != const Color(0xFFF59E0B) ? config.badgeColor : activeLocationColor;
      }

      // Perlindungan ketat: Cegah tag cabang Bali (seperti PCD) bocor ke hasil watermark fisik KC Manado
      if (BranchService.instance.currentBranch == AppBranch.manado) {
        final baliTags = BranchService.instance.getLocationTags(branch: AppBranch.bali);
        if (baliTags.contains(badgeTag.trim().toUpperCase())) {
          badgeTag = activeLocationTag.isNotEmpty && !baliTags.contains(activeLocationTag.trim().toUpperCase())
              ? activeLocationTag
              : 'Absensi';
        }
      }

      final padding = 18.0 * scale;
      final borderRadius = 10.0 * scale;
      // Load custom logo image if any, or fallback to default asset logo
      ui.Image? customLogoUiImage;
      if (config.logoImagePath != null && config.logoImagePath!.isNotEmpty) {
        final logoFile = File(config.logoImagePath!);
        if (logoFile.existsSync()) {
          try {
            final logoBytes = await logoFile.readAsBytes();
            final logoCodec = await ui.instantiateImageCodec(
              logoBytes,
              targetWidth: (120 * scale).toInt(),
            );
            final logoFrame = await logoCodec.getNextFrame();
            customLogoUiImage = logoFrame.image;
          } catch (_) {}
        }
      }
      if (customLogoUiImage == null) {
        try {
          final assetData = await rootBundle.load('foto/bssfotologo_transparent.png');
          final logoBytes = assetData.buffer.asUint8List();
          final logoCodec = await ui.instantiateImageCodec(
            logoBytes,
            targetWidth: (180 * scale).toInt(),
          );
          final logoFrame = await logoCodec.getNextFrame();
          customLogoUiImage = logoFrame.image;
        } catch (_) {}
      }

      // Build text painters for measuring card dimensions
      final badgeTp = TextPainter(
        text: TextSpan(
          text: badgeTag,
          style: TextStyle(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 13.5 * scale,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final timeStr = TimemarkFormatter.formatClockTime(timestamp);
      final timeTp = TextPainter(
        text: TextSpan(
          text: timeStr,
          style: TextStyle(
            color: const Color(0xFF0F2C59),
            fontWeight: FontWeight.w900,
            fontSize: 26.0 * scale,
            letterSpacing: -0.5,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeBoxW = badgeTp.width + (20.0 * scale);
      final timeBoxW = timeTp.width + (24.0 * scale);

      // Logo dimensions (PNG transparan teks putih di atas card biru)
      final double logoH = 34.0 * scale;
      final double logoW;
      if (customLogoUiImage != null && customLogoUiImage.height > 0) {
        final logoAspect = customLogoUiImage.width / customLogoUiImage.height;
        logoW = logoH * logoAspect;
      } else {
        logoW = 76.0 * scale;
      }
      final logoBoxW = logoW + (16.0 * scale);

      final cardW = badgeBoxW + timeBoxW + logoBoxW;
      final cardH = 40.0 * scale;

      // Bottom metadata text
      final dateStr = TimemarkFormatter.formatIndonesianFullDate(timestamp);

      // Card width bounding for metadata text (matches live camera UI where maxWidth is ~280dp)
      // This ensures location address wraps nicely into 2-3 lines instead of stretching across the screen!
      final double cardContentW = math.max(cardW, 280.0 * scale);
      final double maxMetaTextW = (cardContentW - (3.5 * scale) - (12.0 * scale))
          .clamp(200.0 * scale, imgWidth - (padding * 2) - (20.0 * scale));

      final dateTp = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5 * scale,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxMetaTextW);

      TextPainter? addressTp;
      TextPainter? gpsTp;

      if (config.showLocationOnResult) {
        final cleanAddress = LocationService.cleanAddressString(fullAddress);
        final finalAddressText = cleanAddress.isNotEmpty ? cleanAddress : fullAddress;

        addressTp = TextPainter(
          text: TextSpan(
            text: finalAddressText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.0 * scale,
              fontWeight: FontWeight.w500,
              height: 1.25,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          maxLines: 3,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxMetaTextW);

        final gpsStr = TimemarkFormatter.formatGpsDegree(lat, lng);
        gpsTp = TextPainter(
          text: TextSpan(
            text: gpsStr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5 * scale,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxMetaTextW);
      }

      TextPainter? pointTp;
      if (pointLabel != null && pointLabel.trim().isNotEmpty) {
        pointTp = TextPainter(
          text: TextSpan(
            text: 'Poin: ${pointLabel.trim()}',
            style: TextStyle(
              color: const Color(0xFFFDE047),
              fontSize: 11.5 * scale,
              fontWeight: FontWeight.w800,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxMetaTextW);
      }

      final metadataH =
          dateTp.height +
          (pointTp != null ? pointTp.height + (2.5 * scale) : 0) +
          (addressTp != null ? addressTp.height + (3.0 * scale) : 0) +
          (gpsTp != null ? gpsTp.height + (3.0 * scale) : 0);
      final totalWatermarkH = cardH + (10.0 * scale) + metadataH;

      final double metaTextWidth = [
        dateTp.width,
        if (pointTp != null) pointTp.width,
        if (addressTp != null) addressTp.width,
        if (gpsTp != null) gpsTp.width,
      ].fold(0.0, math.max);
      final double totalWatermarkW = math.max(cardW, metaTextWidth + (3.5 * scale) + (12.0 * scale));

      if (config.isShiftTracker) {
        // === MODE SHIFT TRACKER WATERMARK ===
        final lastCheckIn = StorageService.getLastCheckInTime();
        final checkIn = lastCheckIn ?? timestamp.subtract(const Duration(hours: 8, minutes: 19));
        final checkInStr = TimemarkFormatter.formatClockTime(checkIn);
        final nowStr = TimemarkFormatter.formatClockTime(timestamp);
        final diff = timestamp.difference(checkIn);
        final workDurationStr = TimemarkFormatter.formatWorkDuration(diff);

        final isTimeOut = config.badgeTag.toLowerCase().contains('out') ||
            config.customTitle?.toLowerCase().contains('pulang') == true;

        final trackerBadgeTp = TextPainter(
          text: TextSpan(
            text: isTimeOut ? 'Time Out' : 'Time In',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.0 * scale,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final trackerTimeTp = TextPainter(
          text: TextSpan(
            text: nowStr,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 27.0 * scale,
              fontFamily: 'monospace',
              shadows: const [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final verifiedTp = TextPainter(
          text: TextSpan(
            text: '✓ Verified time by Timemark Camera',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 9.5 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // Panel Bawah: On Duty & Work
        final onDutyLblTp = TextPainter(
          text: TextSpan(
            text: 'On duty',
            style: TextStyle(fontSize: 10.0 * scale, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final onDutyValTp = TextPainter(
          text: TextSpan(
            text: '$checkInStr - $nowStr',
            style: TextStyle(
              fontSize: 13.0 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final workLblTp = TextPainter(
          text: TextSpan(
            text: 'Work',
            style: TextStyle(fontSize: 10.0 * scale, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final workValTp = TextPainter(
          text: TextSpan(
            text: workDurationStr,
            style: TextStyle(
              fontSize: 15.0 * scale,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final statusTagTp = TextPainter(
          text: TextSpan(
            text: isTimeOut ? 'pulang' : 'masuk',
            style: TextStyle(fontSize: 10.5 * scale, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final badgeW = trackerBadgeTp.width + (18.0 * scale);
        final badgeH = trackerBadgeTp.height + (8.0 * scale);
        final lineH = dateTp.height + (addressTp != null ? addressTp.height + (2.0 * scale) : 0) + verifiedTp.height + (4.0 * scale);

        final trackerPanelW = (onDutyValTp.width + workValTp.width + (90.0 * scale)).clamp(260.0 * scale, imgWidth - (padding * 2));
        final trackerPanelH = 48.0 * scale;
        final totalTrackerH = badgeH + (8.0 * scale) + lineH + (12.0 * scale) + trackerPanelH;

        final totalTrackerW = math.max(trackerPanelW, totalWatermarkW);
        final safeMarginX = imgWidth * 0.04;
        final safeMarginY = imgHeight * 0.04;
        final availW = math.max(0.0, imgWidth - totalTrackerW - 2 * safeMarginX);
        final availH = math.max(0.0, imgHeight - totalTrackerH - 2 * safeMarginY);
        final startX = safeMarginX + config.positionX.clamp(0.0, 1.0) * availW;
        final startY = safeMarginY + config.positionY.clamp(0.0, 1.0) * availH;

        // 1. Top Badge Pill
        final topBadgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, startY, badgeW, badgeH),
          Radius.circular(14.0 * scale),
        );
        canvas.drawRRect(topBadgeRect, Paint()..color = badgeColor);
        trackerBadgeTp.paint(canvas, Offset(startX + (badgeW - trackerBadgeTp.width) / 2, startY + (badgeH - trackerBadgeTp.height) / 2));

        // Clock next to pill
        trackerTimeTp.paint(canvas, Offset(startX + badgeW + (10.0 * scale), startY + (badgeH - trackerTimeTp.height) / 2));

        // 2. Metadata with Vertical Accent Line
        final metaY = startY + badgeH + (8.0 * scale);
        final lineW = 3.5 * scale;

        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(startX, metaY, lineW, lineH), Radius.circular(2.0 * scale)),
          Paint()..color = badgeColor,
        );

        var curMetaY = metaY;
        final curMetaX = startX + lineW + (8.0 * scale);
        dateTp.paint(canvas, Offset(curMetaX, curMetaY));
        curMetaY += dateTp.height + (2.0 * scale);

        if (addressTp != null) {
          addressTp.paint(canvas, Offset(curMetaX, curMetaY));
          curMetaY += addressTp.height + (2.0 * scale);
        }

        verifiedTp.paint(canvas, Offset(curMetaX, curMetaY));

        // 3. Bottom Statistics Panel
        final panelY = metaY + lineH + (12.0 * scale);
        final panelRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, panelY, trackerPanelW, trackerPanelH),
          Radius.circular(10.0 * scale),
        );
        canvas.drawRRect(
          panelRect.shift(Offset(0, 3.0 * scale)),
          Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * scale),
        );
        canvas.drawRRect(panelRect, Paint()..color = badgeColor);

        // Inside Panel: On Duty
        final onDutyX = startX + (14.0 * scale);
        onDutyLblTp.paint(canvas, Offset(onDutyX, panelY + (8.0 * scale)));
        onDutyValTp.paint(canvas, Offset(onDutyX, panelY + (22.0 * scale)));

        // Work duration
        final workX = onDutyX + onDutyValTp.width + (18.0 * scale);
        workLblTp.paint(canvas, Offset(workX, panelY + (8.0 * scale)));
        workValTp.paint(canvas, Offset(workX, panelY + (20.0 * scale)));

        // Status Tag
        final tagW = statusTagTp.width + (14.0 * scale);
        final tagH = statusTagTp.height + (6.0 * scale);
        final tagX = startX + trackerPanelW - tagW - (12.0 * scale);
        final tagY = panelY + (trackerPanelH - tagH) / 2;
        final tagRect = RRect.fromRectAndRadius(Rect.fromLTWH(tagX, tagY, tagW, tagH), Radius.circular(8.0 * scale));
        canvas.drawRRect(tagRect, Paint()..color = const Color(0xFF0F172A));
        statusTagTp.paint(canvas, Offset(tagX + (tagW - statusTagTp.width) / 2, tagY + (tagH - statusTagTp.height) / 2));
      } else {
        // === MODE STANDAR: INTEGRATED 3-SECTION BANNER ===
        final safeMarginX = imgWidth * 0.04;
        final safeMarginY = imgHeight * 0.04;
        final availW = math.max(0.0, imgWidth - totalWatermarkW - 2 * safeMarginX);
        final availH = math.max(0.0, imgHeight - totalWatermarkH - 2 * safeMarginY);
        final startX = safeMarginX + config.positionX.clamp(0.0, 1.0) * availW;
        final startY = safeMarginY + config.positionY.clamp(0.0, 1.0) * availH;

        // --- DRAW CARD ---
        final cardRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, startY, cardW, cardH),
          Radius.circular(borderRadius),
        );

        // Card shadow
        canvas.drawRRect(
          cardRect.shift(Offset(0, 3.0 * scale)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * scale),
        );

      // Draw Integrated 3-Section Banner (ClipRRect to keep clean rounded corners)
      canvas.save();
      canvas.clipRRect(cardRect);

      // 1. Left Section: Solid Yellow/Amber Location Tag
      canvas.drawRect(
        Rect.fromLTWH(startX, startY, badgeBoxW, cardH),
        Paint()..color = badgeColor,
      );
      badgeTp.paint(
        canvas,
        Offset(
          startX + (badgeBoxW - badgeTp.width) / 2,
          startY + (cardH - badgeTp.height) / 2,
        ),
      );

      // 2. Center Section: White Background with Digital Clock
      final timeStartX = startX + badgeBoxW;
      canvas.drawRect(
        Rect.fromLTWH(timeStartX, startY, timeBoxW, cardH),
        Paint()..color = Colors.white,
      );
      timeTp.paint(
        canvas,
        Offset(
          timeStartX + (timeBoxW - timeTp.width) / 2,
          startY + (cardH - timeTp.height) / 2,
        ),
      );

      // 3. Right Section: Solid Royal Blue / Navy with Logo BSS Parking
      final logoStartX = timeStartX + timeBoxW;
      canvas.drawRect(
        Rect.fromLTWH(logoStartX, startY, logoBoxW, cardH),
        Paint()..color = const Color(0xFF1E448D),
      );

      if (customLogoUiImage != null) {
        final srcW = customLogoUiImage.width.toDouble();
        final srcH = customLogoUiImage.height.toDouble();
        final srcRect = Rect.fromLTWH(0, 0, srcW, srcH);

        // Hitung BoxFit.contain murni agar tidak terdistorsi/gepeng
        final imgAspect = srcW / srcH;
        final targetAspect = logoW / logoH;
        final double renderW;
        final double renderH;
        if (imgAspect > targetAspect) {
          renderW = logoW;
          renderH = logoW / imgAspect;
        } else {
          renderH = logoH;
          renderW = logoH * imgAspect;
        }
        final renderX = logoStartX + (logoBoxW - renderW) / 2;
        final renderY = startY + (cardH - renderH) / 2;
        final dstRect = Rect.fromLTWH(renderX, renderY, renderW, renderH);

        final paint = Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true;
        canvas.drawImageRect(customLogoUiImage, srcRect, dstRect, paint);
      } else {
        final bssTp = TextPainter(
          text: TextSpan(
            text: 'BSS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              fontSize: 16.0 * scale,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pssTp = TextPainter(
          text: TextSpan(
            text: 'PARKING',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 8.0 * scale,
              letterSpacing: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final blockH = bssTp.height + pssTp.height;
        final bssY = startY + (cardH - blockH) / 2;
        bssTp.paint(canvas, Offset(logoStartX + (logoBoxW - bssTp.width) / 2, bssY));
        pssTp.paint(canvas, Offset(logoStartX + (logoBoxW - pssTp.width) / 2, bssY + bssTp.height));
      }

      canvas.restore();

      // --- DRAW METADATA (Date, Address, GPS) with Left Accent Line ---
      final metaStartY = startY + cardH + (8.0 * scale);
      final accentLineW = 3.5 * scale;
      final accentLineH = metadataH;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, metaStartY, accentLineW, accentLineH),
          Radius.circular(2.0 * scale),
        ),
        Paint()..color = badgeColor,
      );

      var metaTextY = metaStartY;
      final metaTextX = startX + accentLineW + (8.0 * scale);

      dateTp.paint(canvas, Offset(metaTextX, metaTextY));
      metaTextY += dateTp.height + (2.0 * scale);

      if (pointTp != null) {
        pointTp.paint(canvas, Offset(metaTextX, metaTextY));
        metaTextY += pointTp.height + (2.0 * scale);
      }

      if (addressTp != null) {
        addressTp.paint(canvas, Offset(metaTextX, metaTextY));
        metaTextY += addressTp.height + (2.0 * scale);
      }

        if (gpsTp != null) {
          gpsTp.paint(canvas, Offset(metaTextX, metaTextY));
        }
      }

      // End recording & render image (Direct rawRgba to isolate -> Ultra Fast <500ms, no slow PNG decoding)
      final picture = recorder.endRecording();
      final outputImg = await picture.toImage(
        imgWidth.toInt(),
        imgHeight.toInt(),
      );
      final byteData = await outputImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData != null) {
        final rgbaBytes = byteData.buffer.asUint8List();
        final jpgBytes = await compute(
          _encodeRgbaToJpegIsolate,
          _RgbaEncodePayload(outputImg.width, outputImg.height, rgbaBytes, jpegQuality),
        );
        if (jpgBytes.isNotEmpty) {
          await file.writeAsBytes(jpgBytes, flush: true);
          sw.stop();
          debugPrint('[Watermark] Sukses burn timemark: ${file.path} (${sw.elapsedMilliseconds}ms, ${jpgBytes.length} bytes)');
        }
      }
    } catch (e, stack) {
      debugPrint('[Watermark] Error applyWatermarkToFile: $e\n$stack');
    }

    return file.path;
  }
}

class _RgbaEncodePayload {
  final int width;
  final int height;
  final Uint8List rgbaBytes;
  final int quality;

  _RgbaEncodePayload(this.width, this.height, this.rgbaBytes, this.quality);
}

Uint8List _encodeRgbaToJpegIsolate(_RgbaEncodePayload payload) {
  try {
    final img = imglib.Image.fromBytes(
      width: payload.width,
      height: payload.height,
      bytes: payload.rgbaBytes.buffer,
      numChannels: 4,
    );
    return Uint8List.fromList(imglib.encodeJpg(img, quality: payload.quality));
  } catch (_) {
    return Uint8List(0);
  }
}
