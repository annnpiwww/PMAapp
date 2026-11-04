import 'web_share_types.dart';

/// Fallback untuk platform non-web: tidak ada share sheet browser.
Future<WebShareOutcome> shareFilesOnWeb({
  required List<WebShareFile> files,
  String? text,
  String? title,
}) async {
  return WebShareOutcome.failed;
}

/// Fallback untuk platform non-web: unduhan browser tidak tersedia.
Future<WebShareOutcome> downloadFilesOnWeb({
  required List<WebShareFile> files,
}) async {
  return WebShareOutcome.failed;
}
