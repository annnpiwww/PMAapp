import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Komponen visual gambar yang aman di semua platform (Android, iOS native, dan Flutter Web/PWA).
/// Menggunakan [Image.network] saat di web (mendukung blob:, http:, data:)
/// dan [Image.file] saat di platform native mobile.
class AppFileImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppFileImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder ??
            (ctx, err, stack) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.grey,
                  size: 24,
                ),
      );
    }

    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      errorBuilder: errorBuilder ??
          (ctx, err, stack) => const Icon(
                Icons.broken_image_rounded,
                color: Colors.grey,
                size: 24,
              ),
    );
  }
}
