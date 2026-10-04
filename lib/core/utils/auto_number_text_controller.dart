import 'package:flutter/material.dart';

/// Controller khusus TextField multiline yang secara otomatis
/// menyisipkan penomoran urut (1. 2. 3. dst) tanpa teknisi harus mengetik angka manual.
class AutoNumberTextController extends TextEditingController {
  bool _isFormatting = false;

  AutoNumberTextController({String? text}) : super(text: text) {
    if (text != null && text.isNotEmpty && text != '-') {
      final formatted = formatNumberedLines(text);
      if (formatted != text && formatted != '-') {
        this.text = formatted;
      }
    }
  }

  /// Memformat teks mentah multi-baris menjadi daftar berpenomoran urut bersih
  static String formatNumberedLines(String? raw) {
    if (raw == null) return '-';
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '-';

    final numberedLines = <String>[];
    int counter = 1;

    for (final line in lines) {
      final numRegex = RegExp(r'^(\d+[\.\)]|\-|\*|\•)\s*');
      final cleanText = numRegex.hasMatch(line)
          ? line.replaceFirst(numRegex, '').trim()
          : line;
      if (cleanText.isNotEmpty) {
        numberedLines.add('$counter. $cleanText');
        counter++;
      }
    }

    return numberedLines.isEmpty ? '-' : numberedLines.join('\n');
  }

  /// Menambahkan baris baru dengan nomor berikutnya secara manual/programatik
  void handleNewline() {
    if (_isFormatting) return;
    final current = text;
    if (current.isEmpty || current == '-') {
      text = '1. ';
      selection = const TextSelection.collapsed(offset: 3);
      return;
    }

    final lines = current
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final nextNum = lines.length + 1;
    final newText = current.endsWith('\n') ? '$current$nextNum. ' : '$current\n$nextNum. ';

    _isFormatting = true;
    text = newText;
    selection = TextSelection.collapsed(offset: newText.length);
    _isFormatting = false;
  }

  @override
  set value(TextEditingValue newValue) {
    if (_isFormatting) {
      super.value = newValue;
      return;
    }

    final oldText = text;
    final newText = newValue.text;

    // 1. Jika mulai mengetik dari kondisi kosong tanpa awalan nomor
    final numPrefixRegex = RegExp(r'^\d+[\.\)]\s*');
    if ((oldText.isEmpty || oldText == '-') &&
        newText.isNotEmpty &&
        newText != '-' &&
        !numPrefixRegex.hasMatch(newText)) {
      _isFormatting = true;
      final updated = '1. $newText';
      final newOffset = (newValue.selection.baseOffset + 3).clamp(0, updated.length);
      super.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: newOffset),
      );
      _isFormatting = false;
      return;
    }

    // 2. Jika user menekan Enter (terdeteksi ada penambahan karakter newline \n)
    if (newText.length > oldText.length && newText.endsWith('\n')) {
      final contentLines = newText
          .substring(0, newText.length - 1)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final nextNum = contentLines.length + 1;
      final updated = '$newText$nextNum. ';
      _isFormatting = true;
      super.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      _isFormatting = false;
      return;
    }

    super.value = newValue;
  }
}
