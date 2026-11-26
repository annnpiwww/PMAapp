import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/utils/share_helper.dart';
import '../../../core/utils/web_share/web_share.dart';
import '../../../core/widgets/tiket/tiket.dart';

/// iOS WhatsApp share extension caps media at ~10 items per invocation.
const int kWebShareChunk = 10;

/// 1-based inclusive photo ranges for batched web sharing (e.g. 1..10, 11..20, 21..23).
List<({int start, int end})> webShareChunks(
  int total, {
  int chunkSize = kWebShareChunk,
}) {
  if (total <= 0 || chunkSize <= 0) return const [];
  final chunks = <({int start, int end})>[];
  for (var start = 1; start <= total; start += chunkSize) {
    final end = start + chunkSize - 1 > total ? total : start + chunkSize - 1;
    chunks.add((start: start, end: end));
  }
  return chunks;
}

String webShareChunkLabel(({int start, int end}) chunk) =>
    chunk.start == chunk.end
        ? 'Kirim foto ${chunk.start}'
        : 'Kirim foto ${chunk.start}-${chunk.end}';

String webSaveChunkLabel(
  ({int start, int end}) chunk, {
  required int savedCount,
  required int totalChunks,
}) {
  if (savedCount <= 0) return 'Simpan semua ke Galeri';
  if (savedCount >= totalChunks) return 'Semua foto tersimpan';
  return chunk.start == chunk.end
      ? 'Simpan foto ${chunk.start}'
      : 'Simpan foto ${chunk.start}-${chunk.end}';
}

typedef WebTextShareHandler = Future<WebShareOutcome> Function({
  required String text,
  required bool telegram,
});

typedef WebFilesShareHandler = Future<WebShareOutcome> Function({
  required List<WebShareFile> files,
  String? text,
  String? title,
});

Future<void> showWebShareBatchSheet(
  BuildContext context, {
  required String text,
  required List<WebShareFile> files,
  required bool telegram,
}) {
  final colors = TiketColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.dialog,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => WebShareBatchSheet(
      text: text,
      files: files,
      telegram: telegram,
    ),
  );
}

class WebShareBatchSheet extends StatefulWidget {
  final String text;
  final List<WebShareFile> files;
  final bool telegram;
  final WebTextShareHandler? onShareText;
  final WebFilesShareHandler? onShareFiles;

  const WebShareBatchSheet({
    super.key,
    required this.text,
    required this.files,
    required this.telegram,
    this.onShareText,
    this.onShareFiles,
  });

  @override
  State<WebShareBatchSheet> createState() => _WebShareBatchSheetState();
}

class _WebShareBatchSheetState extends State<WebShareBatchSheet> {
  bool _textSent = false;
  final Set<int> _sentChunks = <int>{};
  int _savedChunks = 0;

  late List<({int start, int end})> _chunks;

  @override
  void initState() {
    super.initState();
    _chunks = webShareChunks(widget.files.length);
  }

  @override
  void didUpdateWidget(covariant WebShareBatchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.files.length != widget.files.length) {
      _chunks = webShareChunks(widget.files.length);
    }
  }

  // Every tap handler below invokes navigator.share synchronously before any
  // await so Safari iOS preserves user activation.
  void _handleShareText() {
    final shareText = widget.onShareText ?? ShareHelper.shareWebTextOnly;
    final future = shareText(text: widget.text, telegram: widget.telegram);
    unawaited(future.then((outcome) {
      if (!mounted) return;
      if (outcome == WebShareOutcome.shared) {
        setState(() => _textSent = true);
      }
    }));
  }

  void _handleShareChunk(int index) {
    final range = _chunks[index];
    final slice = widget.files.sublist(range.start - 1, range.end);
    final shareFiles = widget.onShareFiles ?? shareFilesOnWeb;
    final future = shareFiles(files: slice, text: null);
    unawaited(future.then((outcome) {
      if (!mounted) return;
      if (outcome == WebShareOutcome.shared) {
        setState(() => _sentChunks.add(index));
      }
    }));
  }

  void _handleSaveNextChunk() {
    if (_chunks.isEmpty) return;
    final nextIndex = _savedChunks < _chunks.length ? _savedChunks : 0;
    final range = _chunks[nextIndex];
    final slice = widget.files.sublist(range.start - 1, range.end);
    final shareFiles = widget.onShareFiles ?? shareFilesOnWeb;
    final future = shareFiles(files: slice, text: null);
    unawaited(future.then((outcome) {
      if (!mounted) return;
      if (outcome == WebShareOutcome.shared ||
          outcome == WebShareOutcome.downloaded) {
        setState(() {
          _savedChunks =
              _savedChunks < _chunks.length ? _savedChunks + 1 : 1;
        });
      }
    }));
  }

  int? get _nextPendingChunkIndex {
    if (!_textSent) return null;
    for (var i = 0; i < _chunks.length; i++) {
      if (!_sentChunks.contains(i)) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = TiketColors.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final nextChunk = _nextPendingChunkIndex;

    final allSaved = _chunks.isNotEmpty && _savedChunks >= _chunks.length;
    final nextSaveChunk = _chunks.isEmpty
        ? null
        : _chunks[_savedChunks < _chunks.length ? _savedChunks : 0];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: colors.mute.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kirim laporan ke grup',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'iPhone cuma bisa kirim 10 foto sekali kirim. Tap tombol berurutan.',
                        style: TextStyle(
                          fontFamily: TiketType.fontFamily,
                          fontSize: 13,
                          height: 1.35,
                          color: colors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                TiketIconButton(
                  icon: Icons.close_rounded,
                  semanticLabel: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.hairline),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TiketPill(
                    key: const Key('web-share-step-text'),
                    label: _textSent
                        ? 'Kirim teks laporan (Terkirim)'
                        : 'Kirim teks laporan',
                    icon: _textSent
                        ? Icons.check_rounded
                        : (widget.telegram
                            ? Icons.send_rounded
                            : Icons.chat_rounded),
                    kind: _textSent
                        ? TiketPillKind.secondary
                        : TiketPillKind.primary,
                    height: 44,
                    expand: true,
                    onPressed: _handleShareText,
                  ),
                  for (var i = 0; i < _chunks.length; i++) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final sent = _sentChunks.contains(i);
                        final baseLabel = webShareChunkLabel(_chunks[i]);
                        return TiketPill(
                          key: Key('web-share-step-chunk-$i'),
                          label: sent ? '$baseLabel (Terkirim)' : baseLabel,
                          icon: sent
                              ? Icons.check_rounded
                              : Icons.photo_library_outlined,
                          kind: !sent && nextChunk == i
                              ? TiketPillKind.primary
                              : TiketPillKind.secondary,
                          height: 44,
                          expand: true,
                          onPressed: () => _handleShareChunk(i),
                        );
                      },
                    ),
                  ],
                  if (nextSaveChunk != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: colors.hairline),
                    ),
                    TiketPill(
                      key: const Key('web-share-save-gallery'),
                      label: webSaveChunkLabel(
                        nextSaveChunk,
                        savedCount: _savedChunks,
                        totalChunks: _chunks.length,
                      ),
                      icon: allSaved
                          ? Icons.check_rounded
                          : Icons.download_rounded,
                      kind: TiketPillKind.secondary,
                      height: 44,
                      expand: true,
                      onPressed: _handleSaveNextChunk,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
