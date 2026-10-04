import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bssparking_timemark/data/repositories/template_repository.dart';
import 'package:bssparking_timemark/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await TemplateRepository.instance.init();
  });

  group('Template Deletion & Reset Tests', () {
    test('Can delete default template by id', () async {
      expect(TemplateRepository.instance.templates.isNotEmpty, isTrue);
      final initialCount = TemplateRepository.instance.templates.length;
      final firstTemplateId = TemplateRepository.instance.templates.first.id;

      await TemplateRepository.instance.deleteTemplate(firstTemplateId);

      expect(TemplateRepository.instance.templates.length, equals(initialCount - 1));
      expect(TemplateRepository.instance.getById(firstTemplateId)?.id, isNot(equals(firstTemplateId)));
    });

    test('Can reset templates back to defaults', () async {
      await TemplateRepository.instance.deleteTemplate(TemplateRepository.defaultTemplates.first.id);
      expect(TemplateRepository.instance.templates.length, isNot(equals(TemplateRepository.defaultTemplates.length)));

      await TemplateRepository.instance.resetToDefaults();
      expect(TemplateRepository.instance.templates.length, equals(TemplateRepository.defaultTemplates.length));
    });
  });
}
