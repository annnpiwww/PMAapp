import 'package:flutter_test/flutter_test.dart';
import 'package:bssparking_timemark/core/utils/auto_number_text_controller.dart';

void main() {
  group('AutoNumberTextController', () {
    test('automatically prefixes 1. when typing on empty controller', () {
      final controller = AutoNumberTextController();
      controller.text = 'Perbaikan printer';
      expect(controller.text, '1. Perbaikan printer');
    });

    test('preserves existing number prefix if already present', () {
      final controller = AutoNumberTextController();
      controller.text = '1. Kalibrasi sensor loop';
      expect(controller.text, '1. Kalibrasi sensor loop');
    });

    test('automatically adds next number on newline', () {
      final controller = AutoNumberTextController(text: '1. Line one');
      controller.handleNewline();
      expect(controller.text, '1. Line one\n2. ');
    });

    test('cleans and formats multi-line raw text sequentially', () {
      final result = AutoNumberTextController.formatNumberedLines('Line one\nLine two\nLine three');
      expect(result, '1. Line one\n2. Line two\n3. Line three');
    });

    test('handles empty or dash gracefully', () {
      expect(AutoNumberTextController.formatNumberedLines(null), '-');
      expect(AutoNumberTextController.formatNumberedLines(''), '-');
      expect(AutoNumberTextController.formatNumberedLines('   -  '), '-');
    });
  });
}
