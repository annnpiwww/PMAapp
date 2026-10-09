import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Komponen visual gambar yang aman di semua platform (Android, iOS native, dan Flutter Web/PWA).
/// Mendukung:
/// 1. [Uint8List] bytes memory rendering (paling aman & tercepat di Web & Mobile)
/// 2. [data:image/...] base64 data URL
/// 3. [blob:...] atau [http:...]/[https:...] di Web
/// 4. [File] di platform native Android / iOS
class AppFileImage extends StatelessWidget {
  final String? path;
  final Uint8List? bytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppFileImage({
    super.key,
    this.path,
    this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.errorBuilder,
  });

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(
          Icons.photo_rounded,
          color: Colors.white38,
          size: 28,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Direct Memory Bytes (Ultra Cepat & 100% Aman di Web & Native)
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        errorBuilder: (ctx, err, stack) =>
            errorBuilder != null ? errorBuilder!(ctx, err, stack) : _buildFallback(ctx),
      );
    }

    final p = path?.trim() ?? '';
    if (p.isEmpty) {
      return _buildFallback(context);
    }

    // 2. Data URL Base64 decoding
    if (p.startsWith('data:image')) {
      try {
        final commaIdx = p.indexOf(',');
        final base64Str = commaIdx != -1 ? p.substring(commaIdx + 1) : p;
        final decoded = base64Decode(base64Str);
        return Image.memory(
          decoded,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          errorBuilder: (ctx, err, stack) =>
              errorBuilder != null ? errorBuilder!(ctx, err, stack) : _buildFallback(ctx),
        );
      } catch (_) {
        return _buildFallback(context);
      }
    }

    // 3. Platform Web (Network / Blob URL)
    if (kIsWeb) {
      return Image.network(
        p,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (ctx, err, stack) =>
            errorBuilder != null ? errorBuilder!(ctx, err, stack) : _buildFallback(ctx),
      );
    }

    // 4. Platform Native Mobile (File Storage)
    try {
      final file = File(p);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          errorBuilder: (ctx, err, stack) =>
              errorBuilder != null ? errorBuilder!(ctx, err, stack) : _buildFallback(ctx),
        );
      }
    } catch (_) {}

    return _buildFallback(context);
  }
}
